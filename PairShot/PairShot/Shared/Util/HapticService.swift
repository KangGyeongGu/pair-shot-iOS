import UIKit

enum HapticImpactStyle: Equatable {
    case light
    case medium
    case heavy
    case soft
    case rigid

    var uikit: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
            case .light: .light
            case .medium: .medium
            case .heavy: .heavy
            case .soft: .soft
            case .rigid: .rigid
        }
    }
}

enum HapticNotificationKind: Equatable {
    case success
    case warning
    case error

    var uikit: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
            case .success: .success
            case .warning: .warning
            case .error: .error
        }
    }
}

final class HapticService {
    init() {}

    func impact(_ style: HapticImpactStyle) {
        let generator = UIImpactFeedbackGenerator(style: style.uikit)
        generator.prepare()
        generator.impactOccurred()
    }

    func notify(_ kind: HapticNotificationKind) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(kind.uikit)
    }
}
