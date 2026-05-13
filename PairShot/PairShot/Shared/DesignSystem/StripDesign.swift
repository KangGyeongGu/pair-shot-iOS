import SwiftUI

enum StripDesign {
    static let cardAspectRatio: CGFloat = 100.0 / 134.0
    static let cardHeightRatio: CGFloat = 134.0 / 168.0
    static let paddingVerticalRatio: CGFloat = 17.0 / 168.0
    static let cardSpacingRatio: CGFloat = 8.0 / 134.0
    static let cornerRadiusRatio: CGFloat = 10.0 / 134.0

    static let stripPaddingHorizontal: CGFloat = 20

    static let activeScale: CGFloat = 1.0
    static let inactiveScale: CGFloat = 0.85

    static let activeBorderColor: Color = .yellow
    static let activeBorderWidth: CGFloat = 3
    static let inactiveBorderColor: Color = .white.opacity(0.3)
    static let inactiveBorderWidth: CGFloat = 1

    static func cardHeight(stripHeight: CGFloat) -> CGFloat {
        max(0, stripHeight * cardHeightRatio)
    }

    static func cardWidth(stripHeight: CGFloat) -> CGFloat {
        cardHeight(stripHeight: stripHeight) * cardAspectRatio
    }

    static func cardSpacing(stripHeight: CGFloat) -> CGFloat {
        cardHeight(stripHeight: stripHeight) * cardSpacingRatio
    }

    static func cornerRadius(stripHeight: CGFloat) -> CGFloat {
        cardHeight(stripHeight: stripHeight) * cornerRadiusRatio
    }

    static func paddingVertical(stripHeight: CGFloat) -> CGFloat {
        max(0, stripHeight * paddingVerticalRatio)
    }
}
