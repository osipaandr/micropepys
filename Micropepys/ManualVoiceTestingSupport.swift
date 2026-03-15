import AppKit
import Foundation
import Combine
import OSLog
import MicropepysCore

struct ManualVoiceFixture: Identifiable, Hashable {
    let fileURL: URL

    var id: String { fileURL.lastPathComponent }
    var displayName: String { fileURL.deletingPathExtension().lastPathComponent }
}

struct ManualVoiceMappingResult {
    let operations: [ChecklistOperation]
    let warnings: [String]
}

@MainActor
final class ManualVoiceTestHarness: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.github.osipaandr.Micropepys",
        category: "ManualVoiceTesting"
    )
    nonisolated private static let fixturesBookmarkStorageKey = "ManualVoiceTestingFixturesDirectoryBookmark"
    nonisolated private static let backendBaseURLStorageKey = "ManualVoiceTestingBackendBaseURL"

    @Published var backendBaseURLText: String
    @Published private(set) var fixturesDirectoryPath: String
    @Published private(set) var fixtures: [ManualVoiceFixture] = []
    @Published var selectedFixtureID: String = ""
    @Published private(set) var isRunning = false
    @Published private(set) var statusMessage = "Select a fixture and send it to the backend."
    @Published private(set) var lastFixtureName: String?
    @Published private(set) var lastTranscript: String?
    @Published private(set) var lastConfidence: Double?
    @Published private(set) var lastTransactionID: String?
    @Published private(set) var lastRawOperations: [String] = []
    @Published private(set) var lastAppliedOperations: [String] = []
    @Published private(set) var lastWarnings: [String] = []
    @Published private(set) var lastErrorMessage: String?

    @Published private(set) var requiresFixtureDirectoryAccess = false

    private var fixturesDirectoryURL: URL
    private var latestResponse: VoiceUpdateResponse?
    private var securityScopedFixturesDirectoryURL: URL?

    init(
        backendBaseURLText: String = ManualVoiceTestHarness.defaultBackendBaseURLText(),
        fixturesDirectoryURL: URL = ManualVoiceTestHarness.defaultFixturesDirectoryURL()
    ) {
        let restoredFixturesDirectoryURL = Self.restoreFixturesDirectoryURL()
        self.backendBaseURLText = backendBaseURLText
        self.fixturesDirectoryURL = restoredFixturesDirectoryURL ?? fixturesDirectoryURL
        self.fixturesDirectoryPath = fixturesDirectoryURL.path
        self.fixturesDirectoryPath = self.fixturesDirectoryURL.path
        self.securityScopedFixturesDirectoryURL = restoredFixturesDirectoryURL
        refreshFixtures()
    }

    func refreshFixtures() {
        let fileManager = FileManager.default
        lastErrorMessage = nil
        do {
            let urls = try fileManager.contentsOfDirectory(
                at: fixturesDirectoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            fixtures = urls
                .filter { $0.pathExtension.lowercased() == "wav" }
                .map(ManualVoiceFixture.init(fileURL:))
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            if fixtures.isEmpty {
                statusMessage = fileManager.fileExists(atPath: fixturesDirectoryURL.path)
                    ? "No .wav fixtures found in \(fixturesDirectoryURL.lastPathComponent)."
                    : "Fixture directory does not exist yet."
            } else if !fixtures.contains(where: { $0.id == selectedFixtureID }) {
                selectedFixtureID = fixtures[0].id
            }
            requiresFixtureDirectoryAccess = false
            Self.logger.debug("Loaded \(self.fixtures.count) voice fixture(s) from \(self.fixturesDirectoryURL.path, privacy: .public)")
        } catch {
            fixtures = []
            requiresFixtureDirectoryAccess = Self.isPermissionError(error)
            statusMessage = requiresFixtureDirectoryAccess
                ? "App needs permission to read the fixture directory."
                : "Failed to read fixture directory."
            lastErrorMessage = error.localizedDescription
            Self.logger.error("Failed to load fixtures from \(self.fixturesDirectoryURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func persistBackendBaseURL() {
        let trimmed = backendBaseURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: Self.backendBaseURLStorageKey)
        Self.logger.info("Persisted backend URL \(trimmed, privacy: .public)")
    }

    func chooseFixturesDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.prompt = "Grant Access"
        panel.message = "Choose the folder that contains manual voice fixtures."
        panel.directoryURL = fixturesDirectoryURL.deletingLastPathComponent()

        guard panel.runModal() == .OK, let url = panel.url else {
            statusMessage = "Fixture directory selection was cancelled."
            return
        }

        do {
            try persistFixturesDirectoryAccess(url)
            fixturesDirectoryURL = url
            fixturesDirectoryPath = url.path
            statusMessage = "Granted access to fixture directory."
            refreshFixtures()
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Failed to store fixture directory access."
            Self.logger.error("Failed to store fixture directory access for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func sendSelectedFixture(using manager: ChecklistManager) async {
        guard let fixture = selectedFixture else {
            lastErrorMessage = "No WAV fixture selected."
            statusMessage = "Select a fixture before sending."
            return
        }

        guard let baseURL = normalizedBackendBaseURL() else {
            lastErrorMessage = "Backend URL is invalid."
            statusMessage = "Fix the backend URL and try again."
            return
        }

        do {
            isRunning = true
            lastErrorMessage = nil
            lastAppliedOperations = []
            lastWarnings = []
            statusMessage = "Sending \(fixture.fileURL.lastPathComponent)..."

            let audioData = try Data(contentsOf: fixture.fileURL)
            let request = VoiceUpdateRequest(
                audioData: audioData,
                checklistItems: manager.readAll()
            )

            let client = VoiceUpdateClient(baseURL: baseURL)
            Self.logger.info("Sending fixture \(fixture.fileURL.lastPathComponent, privacy: .public) to \(baseURL.absoluteString, privacy: .public)")
            let response = try await client.sendVoiceUpdate(request)

            latestResponse = response
            lastFixtureName = fixture.fileURL.lastPathComponent
            lastTranscript = response.transcript
            lastConfidence = response.confidence
            lastTransactionID = response.transactionId
            lastRawOperations = response.operations.map(Self.describeVoiceOperation)
            statusMessage = response.operations.isEmpty
                ? "Backend returned a no-op response."
                : "Backend returned \(response.operations.count) operation(s)."
            Self.logger.info("Received response for \(fixture.fileURL.lastPathComponent, privacy: .public): transcriptLength=\(response.transcript.count), operations=\(response.operations.count), confidence=\(response.confidence)")
        } catch {
            latestResponse = nil
            lastFixtureName = fixture.fileURL.lastPathComponent
            lastTranscript = nil
            lastConfidence = nil
            lastTransactionID = nil
            lastRawOperations = []
            lastAppliedOperations = []
            lastWarnings = []
            lastErrorMessage = Self.describeError(error)
            statusMessage = "Voice update request failed."
            Self.logger.error("Voice update failed for \(fixture.fileURL.lastPathComponent, privacy: .public): \(self.lastErrorMessage ?? error.localizedDescription, privacy: .public)")
        }

        isRunning = false
    }

    func sendAndApplySelectedFixture(using manager: ChecklistManager) async {
        await sendSelectedFixture(using: manager)
        guard latestResponse != nil else { return }
        applyLatestResponse(using: manager)
    }

    func applyLatestResponse(using manager: ChecklistManager) {
        guard let response = latestResponse else {
            lastErrorMessage = "No backend response available to apply."
            statusMessage = "Send a fixture first."
            return
        }

        let mapping = Self.mapVoiceOperations(response.operations, onto: manager.readAll())
        lastWarnings = mapping.warnings
        lastAppliedOperations = mapping.operations.map(Self.describeChecklistOperation)

        guard !mapping.operations.isEmpty else {
            statusMessage = response.operations.isEmpty
                ? "No-op response. Nothing to apply."
                : "No checklist operations were applied."
            return
        }

        manager.apply(operations: mapping.operations)
        statusMessage = "Applied \(mapping.operations.count) operation(s) to the checklist."
        Self.logger.info("Applied \(mapping.operations.count) checklist operation(s); warnings=\(mapping.warnings.count)")
    }

    var selectedFixture: ManualVoiceFixture? {
        fixtures.first(where: { $0.id == selectedFixtureID })
    }

    private func normalizedBackendBaseURL() -> URL? {
        let trimmed = backendBaseURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    nonisolated private static func defaultBackendBaseURLText() -> String {
        if
            let persistedValue = UserDefaults.standard.string(forKey: backendBaseURLStorageKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !persistedValue.isEmpty
        {
            return persistedValue
        }

        return FrontendLocalEnvironment.load().backendBaseURL ?? "http://127.0.0.1:8787"
    }

    nonisolated private static func defaultFixturesDirectoryURL() -> URL {
        if let configuredPath = FrontendLocalEnvironment.load().voiceFixturesDirectory {
            return URL(fileURLWithPath: configuredPath, isDirectory: true)
        }

        var sourceFileURL = URL(fileURLWithPath: #filePath)
        sourceFileURL.deleteLastPathComponent()
        sourceFileURL.deleteLastPathComponent()
        return sourceFileURL
            .appendingPathComponent("docs", isDirectory: true)
            .appendingPathComponent("voice-fixtures", isDirectory: true)
    }

    private func persistFixturesDirectoryAccess(_ url: URL) throws {
        releaseSecurityScopedAccess()

        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: Self.fixturesBookmarkStorageKey)

        if url.startAccessingSecurityScopedResource() {
            securityScopedFixturesDirectoryURL = url
            Self.logger.info("Started security-scoped access for \(url.path, privacy: .public)")
        } else {
            Self.logger.error("Failed to start security-scoped access for \(url.path, privacy: .public)")
        }
    }

    private func releaseSecurityScopedAccess() {
        securityScopedFixturesDirectoryURL?.stopAccessingSecurityScopedResource()
        securityScopedFixturesDirectoryURL = nil
    }

    nonisolated private static func restoreFixturesDirectoryURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: fixturesBookmarkStorageKey) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale {
            UserDefaults.standard.removeObject(forKey: fixturesBookmarkStorageKey)
            return nil
        }

        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    nonisolated private static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError
    }

    private static func describeVoiceOperation(_ operation: VoiceUpdateOperation) -> String {
        switch operation {
        case let .complete(id):
            return "complete(id: \(id))"
        case let .add(title):
            return "add(title: \(title))"
        case let .edit(id, title, isCompleted):
            return "edit(id: \(id), title: \(title ?? "nil"), isCompleted: \(isCompleted.map(String.init) ?? "nil"))"
        case let .remove(id):
            return "remove(id: \(id))"
        case let .move(id, toIndex):
            return "move(id: \(id), toIndex: \(toIndex))"
        }
    }

    private static func describeChecklistOperation(_ operation: ChecklistOperation) -> String {
        switch operation {
        case let .complete(id):
            return "complete(id: \(id.uuidString))"
        case let .add(title):
            return "add(title: \(title))"
        case let .edit(id, title, isCompleted):
            return "edit(id: \(id.uuidString), title: \(title ?? "nil"), isCompleted: \(isCompleted.map(String.init) ?? "nil"))"
        case let .remove(id):
            return "remove(id: \(id.uuidString))"
        case let .move(source, destination):
            return "move(source: \(source.sorted()), destination: \(destination))"
        }
    }

    private static func describeError(_ error: Error) -> String {
        if let clientError = error as? VoiceUpdateClientError {
            switch clientError {
            case .invalidEndpoint:
                return "Invalid /voice-update endpoint."
            case .nonHTTPResponse:
                return "Backend returned a non-HTTP response."
            case let .requestFailed(statusCode, code, message):
                if statusCode == 422, code == "stt_audio_decode_failed" {
                    return "Backend could not decode this WAV file. Re-export the fixture as a standard PCM WAV file and try again."
                }
                return "HTTP \(statusCode) \(code ?? "backend_error"): \(message ?? "No message")"
            case .decodingFailed:
                return "Backend response could not be decoded."
            }
        }

        return error.localizedDescription
    }

    private static func mapVoiceOperations(
        _ voiceOperations: [VoiceUpdateOperation],
        onto initialItems: [ChecklistItem]
    ) -> ManualVoiceMappingResult {
        var simulatedItems = initialItems
        var mappedOperations: [ChecklistOperation] = []
        var warnings: [String] = []

        for operation in voiceOperations {
            switch operation {
            case let .complete(id):
                guard let uuid = UUID(uuidString: id) else {
                    warnings.append("Skipped complete for invalid UUID: \(id)")
                    continue
                }
                guard let index = simulatedItems.firstIndex(where: { $0.id == uuid }) else {
                    warnings.append("Skipped complete for unknown item id: \(id)")
                    continue
                }
                guard !simulatedItems[index].isCompleted else { continue }

                simulatedItems[index].isCompleted = true
                mappedOperations.append(.complete(id: uuid))

            case let .add(title):
                simulatedItems.append(ChecklistItem(title: title))
                mappedOperations.append(.add(title: title))

            case let .edit(id, title, isCompleted):
                guard let uuid = UUID(uuidString: id) else {
                    warnings.append("Skipped edit for invalid UUID: \(id)")
                    continue
                }
                guard let index = simulatedItems.firstIndex(where: { $0.id == uuid }) else {
                    warnings.append("Skipped edit for unknown item id: \(id)")
                    continue
                }

                let previous = simulatedItems[index]
                var updated = previous
                if let title {
                    updated.title = title
                }
                if let isCompleted {
                    updated.isCompleted = isCompleted
                }
                guard updated != previous else { continue }

                simulatedItems[index] = updated
                mappedOperations.append(.edit(id: uuid, title: title, isCompleted: isCompleted))

            case let .remove(id):
                guard let uuid = UUID(uuidString: id) else {
                    warnings.append("Skipped remove for invalid UUID: \(id)")
                    continue
                }
                guard let index = simulatedItems.firstIndex(where: { $0.id == uuid }) else {
                    warnings.append("Skipped remove for unknown item id: \(id)")
                    continue
                }

                simulatedItems.remove(at: index)
                mappedOperations.append(.remove(id: uuid))

            case let .move(id, toIndex):
                guard let uuid = UUID(uuidString: id) else {
                    warnings.append("Skipped move for invalid UUID: \(id)")
                    continue
                }
                guard let sourceIndex = simulatedItems.firstIndex(where: { $0.id == uuid }) else {
                    warnings.append("Skipped move for unknown item id: \(id)")
                    continue
                }

                let source = IndexSet(integer: sourceIndex)
                guard source.first != toIndex, source.first != toIndex - 1 else { continue }

                var movingItems: [ChecklistItem] = []
                for index in source.sorted(by: >) {
                    movingItems.insert(simulatedItems.remove(at: index), at: 0)
                }

                let destination = max(0, min(toIndex, simulatedItems.count))
                simulatedItems.insert(contentsOf: movingItems, at: destination)
                mappedOperations.append(.move(source: source, destination: destination))
            }
        }

        return ManualVoiceMappingResult(operations: mappedOperations, warnings: warnings)
    }
}
