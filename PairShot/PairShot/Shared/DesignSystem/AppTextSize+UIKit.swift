import UIKit

extension AppTextSize {
    var preferredContentSizeCategory: UIContentSizeCategory {
        switch self {
            case .small: .small
            case .medium: .large
            case .large: .extraLarge
            case .extraLarge: .extraExtraLarge
        }
    }
}
