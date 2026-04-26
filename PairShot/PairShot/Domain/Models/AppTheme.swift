import Foundation
import SwiftUI

enum AppTheme: String, Codable, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
            case .system: String(localized: "시스템 기본값")
            case .light: String(localized: "라이트")
            case .dark: String(localized: "다크")
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
