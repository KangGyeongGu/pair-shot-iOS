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
    let width: CGFloat?
    let height: CGFloat?

    init(
        image: UIImage?,
        alpha: Double,
        isEnabled: Bool = true,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) {
        self.image = image
        self.alpha = alpha
        self.isEnabled = isEnabled
        self.width = width
        self.height = height
    }

    var body: some View {
        Group {
            if isEnabled, let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
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
