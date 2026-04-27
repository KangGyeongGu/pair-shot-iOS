import Foundation
import SwiftUI
import UIKit

enum GhostOverlayMath {
    static let alphaRange: ClosedRange<Double> = 0.0 ... 1.0
    static let defaultAlpha: Double = 0.5

    static func clamp(_ value: Double) -> Double {
        max(alphaRange.lowerBound, min(value, alphaRange.upperBound))
    }
}

enum GhostOverlayLoader {
    static func loadImage(
        beforeFileName: String,
        storage: PhotoStorageService
    ) -> UIImage? {
        assert(!Thread.isMainThread, "GhostOverlayLoader.loadImage must be called off the main thread")
        guard !beforeFileName.isEmpty else { return nil }
        guard let url = storage.resolveBefore(fileName: beforeFileName) else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
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
