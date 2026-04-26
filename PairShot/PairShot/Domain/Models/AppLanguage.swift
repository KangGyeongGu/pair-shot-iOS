import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case system
    case korean
    case english

    var displayName: String {
        switch self {
            case .system: String(localized: "시스템 기본값")
            case .korean: String(localized: "한국어")
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
}
