import Foundation

struct FrontendLocalEnvironment {
    let backendBaseURL: String?
    let voiceFixturesDirectory: String?

    nonisolated static func load(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> FrontendLocalEnvironment {
        return FrontendLocalEnvironment(
            backendBaseURL: processEnvironment["MICROPEPYS_BACKEND_BASE_URL"],
            voiceFixturesDirectory: processEnvironment["MICROPEPYS_VOICE_FIXTURES_DIR"]
        )
    }
}
