import Foundation
import ImageIO
import SwiftUI
import UIKit

enum GhostOverlayMath {
    static let alphaRange: ClosedRange<Double> = 0.0 ... 1.0
    static let defaultAlpha: Double = 0.35

    static func clamp(_ value: Double) -> Double {
        max(alphaRange.lowerBound, min(value, alphaRange.upperBound))
    }
}

@MainActor
enum GhostOverlayLoader {
    static func loadImage(
        localIdentifier: String,
        photoLibrary: PhotoLibraryService
    ) async -> UIImage? {
        guard !localIdentifier.isEmpty else { return nil }
        guard let data = await photoLibrary.requestImageData(localIdentifier: localIdentifier) else {
            return nil
        }
        guard let cgImage = UIImage(data: data)?.cgImage else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}

struct GhostOverlayView: View {
    let image: UIImage?
    let alpha: Double
    let isEnabled: Bool
    let rotationDegrees: Double
    let width: CGFloat?
    let height: CGFloat?

    init(
        image: UIImage?,
        alpha: Double,
        isEnabled: Bool = true,
        rotationDegrees: Double = 0,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) {
        self.image = image
        self.alpha = alpha
        self.isEnabled = isEnabled
        self.rotationDegrees = rotationDegrees
        self.width = width
        self.height = height
    }

    var body: some View {
        Group {
            if isEnabled, let image, let width, let height {
                let isQuarterTurn = GhostOverlayRotation.isQuarterTurn(rotationDegrees)
                let innerWidth = isQuarterTurn ? height : width
                let innerHeight = isQuarterTurn ? width : height
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: innerWidth, height: innerHeight)
                    .rotationEffect(.degrees(rotationDegrees))
                    .frame(width: width, height: height)
                    .opacity(GhostOverlayMath.clamp(alpha))
            } else {
                Color.black.opacity(0.001)
                    .frame(width: width, height: height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum GhostOverlayRotation {
    static func isQuarterTurn(_ degrees: Double) -> Bool {
        let absDegrees = abs(degrees.truncatingRemainder(dividingBy: 180))
        return absDegrees > 0.5 && absDegrees < 179.5
    }
}
