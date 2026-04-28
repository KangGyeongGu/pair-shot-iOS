import SwiftUI

extension AppTheme {
    var preferredColorScheme: ColorScheme? {
        switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
        }
    }
}

extension AppSettings {
    var resolvedColorScheme: ColorScheme? {
        theme.preferredColorScheme
    }
}
