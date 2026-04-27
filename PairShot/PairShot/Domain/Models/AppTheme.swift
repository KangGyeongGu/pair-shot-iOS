import Foundation
import SwiftUI

nonisolated enum AppTheme: String, Codable, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
            case .system: String(localized: "theme_system")
            case .light: String(localized: "theme_light")
            case .dark: String(localized: "theme_dark")
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
        }
    }
}
