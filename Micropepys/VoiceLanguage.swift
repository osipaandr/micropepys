import Foundation

enum VoiceLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"

    var id: String {
        rawValue
    }

    var languageHint: String {
        rawValue
    }

    var displayTitle: String {
        switch self {
        case .english:
            return "🇬🇧 english"
        case .russian:
            return "🇷🇺 русский"
        }
    }
}
