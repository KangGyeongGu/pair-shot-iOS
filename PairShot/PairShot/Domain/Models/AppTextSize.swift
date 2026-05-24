import Foundation
import SwiftUI

nonisolated enum AppTextSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge

    static let `default`: AppTextSize = .medium

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
            case .small: String(localized: "settings_text_size_small")
            case .medium: String(localized: "settings_text_size_medium")
            case .large: String(localized: "settings_text_size_large")
            case .extraLarge: String(localized: "settings_text_size_extra_large")
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
            case .small: .small
            case .medium: .large
            case .large: .xLarge
            case .extraLarge: .xxLarge
        }
    }
}
