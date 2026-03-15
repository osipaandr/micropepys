import Foundation

enum VoiceBackendConfiguration {
    nonisolated private static let backendBaseURLStorageKey = "ManualVoiceTestingBackendBaseURL"

    nonisolated static func persistedBaseURLText() -> String? {
        guard
            let value = UserDefaults.standard.string(forKey: backendBaseURLStorageKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return nil
        }

        return value
    }

    nonisolated static func defaultBaseURLText() -> String {
        if let persistedValue = persistedBaseURLText() {
            return persistedValue
        }

        return FrontendLocalEnvironment.load().backendBaseURL ?? "http://127.0.0.1:8787"
    }

    nonisolated static func currentBaseURL() -> URL? {
        normalizedBaseURL(from: defaultBaseURLText())
    }

    nonisolated static func persist(baseURLText: String) {
        let trimmed = baseURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: backendBaseURLStorageKey)
    }

    nonisolated static func normalizedBaseURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
