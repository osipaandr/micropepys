import Combine
import Foundation

@MainActor
final class VoiceSettings: ObservableObject {
    @Published var language: VoiceLanguage {
        didSet {
            userDefaults.set(language.rawValue, forKey: Self.languageStorageKey)
        }
    }

    private static let languageStorageKey = "VoiceLanguagePreference"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if
            let persistedValue = userDefaults.string(forKey: Self.languageStorageKey),
            let language = VoiceLanguage(rawValue: persistedValue)
        {
            self.language = language
        } else {
            self.language = .english
        }
    }
}
