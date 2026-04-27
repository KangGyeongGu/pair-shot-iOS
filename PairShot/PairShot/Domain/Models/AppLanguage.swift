import Foundation

nonisolated enum AppLanguage: String, Codable, CaseIterable {
    case system
    case korean
    case english

    var displayName: String {
        switch self {
            case .system: String(localized: "language_system")
            case .korean: String(localized: "language_korean")
            case .english: String(localized: "English")
        }
    }

    var locale: Locale? {
        switch self {
            case .system: nil
            case .korean: Locale(identifier: "ko")
            case .english: Locale(identifier: "en")
        }
    }

    var appleLanguagesIdentifier: String? {
        switch self {
            case .system: nil
            case .korean: "ko"
            case .english: "en"
        }
    }
}

enum AppLanguageBundleSync {
    static let appleLanguagesKey = "AppleLanguages"

    static func apply(_ language: AppLanguage, defaults: UserDefaults = .standard) {
        if let identifier = language.appleLanguagesIdentifier {
            defaults.set([identifier], forKey: appleLanguagesKey)
        } else {
            defaults.removeObject(forKey: appleLanguagesKey)
        }
    }
}
