import Foundation
import SwiftUI
import UIKit

enum GhostOverlayMath {
    static let alphaRange: ClosedRange<Double> = 0.0 ... 1.0
    static let defaultAlpha: Double = 0.35

    static func clamp(_ value: Double) -> Double {
        max(alphaRange.lowerBound, min(value, alphaRange.upperBound))
    }
}

private func isQuarterTurn(_ degrees: Double) -> Bool {
    abs(abs(degrees) - 90.0) < 0.5
}

struct GhostOverlayView: View {
    let image: UIImage?
    let alpha: Double
    let isEnabled: Bool
    let rotationDegrees: Double
    let width: CGFloat?
    let height: CGFloat?

    var body: some View {
        Group {
            if isEnabled, let image, let width, let height {
                rotatedImage(image: image, width: width, height: height)
            } else {
                Color.black.opacity(0.001)
                    .frame(width: width, height: height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    init(
        image: UIImage?,
        alpha: Double,
        isEnabled: Bool = true,
        rotationDegrees: Double = 0,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
    ) {
        self.image = image
        self.alpha = alpha
        self.isEnabled = isEnabled
        self.rotationDegrees = rotationDegrees
        self.width = width
        self.height = height
    }

    @ViewBuilder
    private func rotatedImage(image: UIImage, width: CGFloat, height: CGFloat) -> some View {
        let swap = isQuarterTurn(rotationDegrees)
        let innerWidth = swap ? height : width
        let innerHeight = swap ? width : height

        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: innerWidth, height: innerHeight)
            .rotationEffect(.degrees(rotationDegrees))
            .frame(width: width, height: height)
            .opacity(GhostOverlayMath.clamp(alpha))
    }
}
