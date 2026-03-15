import Combine
import Foundation
import MicropepysCore
import OSLog

enum VoiceFlowState: Equatable {
    case idle
    case recording
    case sending
}

@MainActor
final class VoiceFlowController: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.github.osipaandr.Micropepys",
        category: "VoiceFlow"
    )

    @Published private(set) var flowState: VoiceFlowState = .idle
    @Published private(set) var statusMessage = "Press Record Voice Update to dictate a checklist change."
    @Published private(set) var lastTranscript: String?
    @Published private(set) var lastConfidence: Double?
    @Published private(set) var lastTransactionID: String?
    @Published private(set) var lastAppliedOperations: [String] = []
    @Published private(set) var lastWarnings: [String] = []
    @Published private(set) var lastErrorMessage: String?

    private let checklistManager: ChecklistManager
    private let voiceSettings: VoiceSettings
    private let recorder = VoiceAudioRecorder()

    init(checklistManager: ChecklistManager, voiceSettings: VoiceSettings) {
        self.checklistManager = checklistManager
        self.voiceSettings = voiceSettings
    }

    var isRecording: Bool {
        flowState == .recording
    }

    var isSending: Bool {
        flowState == .sending
    }

    var actionTitle: String {
        switch flowState {
        case .idle:
            return "Record Voice Update"
        case .recording:
            return "Stop And Apply"
        case .sending:
            return "Sending Voice Update..."
        }
    }

    func toggleRecording() async {
        switch flowState {
        case .idle:
            await startRecording()
        case .recording:
            await stopRecordingAndSend()
        case .sending:
            return
        }
    }

    func cancelRecording() {
        guard flowState == .recording else { return }
        recorder.cancelRecording()
        flowState = .idle
        statusMessage = "Voice recording cancelled."
        lastErrorMessage = nil
    }

    private func startRecording() async {
        lastErrorMessage = nil
        lastWarnings = []

        let hasPermission = await recorder.requestPermissionIfNeeded()
        guard hasPermission else {
            flowState = .idle
            lastErrorMessage = "Microphone access is required for voice updates. Allow microphone access in System Settings and try again."
            statusMessage = "Microphone access was denied."
            return
        }

        do {
            try recorder.startRecording()
            flowState = .recording
            statusMessage = "Recording voice update. Trigger the shortcut again or press Stop And Apply when done."
            Self.logger.info("Started microphone recording for voice update")
        } catch {
            flowState = .idle
            lastErrorMessage = error.localizedDescription
            statusMessage = "Failed to start microphone recording."
            Self.logger.error("Failed to start microphone recording: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func stopRecordingAndSend() async {
        do {
            let audioData = try recorder.stopRecording()
            flowState = .sending
            statusMessage = "Sending voice update to backend..."
            lastErrorMessage = nil
            lastAppliedOperations = []
            lastWarnings = []

            guard let baseURL = VoiceBackendConfiguration.currentBaseURL() else {
                flowState = .idle
                lastErrorMessage = "Backend URL is invalid."
                statusMessage = "Fix the backend URL configuration and try again."
                return
            }

            let request = VoiceUpdateRequest(
                audioData: audioData,
                languageHint: voiceSettings.language.languageHint,
                checklistItems: checklistManager.readAll()
            )
            let response = try await VoiceUpdateClient(baseURL: baseURL).sendVoiceUpdate(request)

            lastTranscript = response.transcript
            lastConfidence = response.confidence
            lastTransactionID = response.transactionId

            let mapping = VoiceUpdateOperationMapper.map(
                response.operations,
                onto: checklistManager.readAll()
            )

            lastWarnings = mapping.warnings
            lastAppliedOperations = mapping.operations.map(Self.describeChecklistOperation)

            if response.operations.isEmpty {
                statusMessage = "Voice update produced no changes."
                flowState = .idle
                Self.logger.info("Voice update completed with no-op response; confidence=\(response.confidence)")
                return
            }

            if mapping.operations.isEmpty {
                statusMessage = "Voice update returned operations that could not be applied."
                flowState = .idle
                Self.logger.error("Voice update operations could not be mapped; warnings=\(mapping.warnings.count)")
                return
            }

            checklistManager.apply(operations: mapping.operations)
            statusMessage = "Applied \(mapping.operations.count) voice operation(s). Undo is available with Cmd+Z."
            flowState = .idle
            Self.logger.info("Applied \(mapping.operations.count) voice operation(s); warnings=\(mapping.warnings.count)")
        } catch {
            flowState = .idle
            lastAppliedOperations = []
            lastWarnings = []
            lastErrorMessage = VoiceUpdateErrorInterpreter.message(for: error)
            statusMessage = "Voice update request failed."
            Self.logger.error("Voice update request failed: \(self.lastErrorMessage ?? error.localizedDescription, privacy: .public)")
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
}
