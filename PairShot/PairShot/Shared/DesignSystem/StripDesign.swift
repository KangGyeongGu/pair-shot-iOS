import SwiftUI

enum StripDesign {
    static let cardWidth: CGFloat = 100
    static let cardHeight: CGFloat = 134
    static let cardCornerRadius: CGFloat = 10
    static let cardSpacing: CGFloat = 8

    static let stripPaddingVertical: CGFloat = 17
    static let stripPaddingHorizontal: CGFloat = 20
    static let stripHeight: CGFloat = cardHeight + stripPaddingVertical * 2

    static let activeScale: CGFloat = 1.0
    static let inactiveScale: CGFloat = 0.85

    static let activeBorderColor: Color = .yellow
    static let activeBorderWidth: CGFloat = 3
    static let inactiveBorderColor: Color = .white.opacity(0.3)
    static let inactiveBorderWidth: CGFloat = 1
}
