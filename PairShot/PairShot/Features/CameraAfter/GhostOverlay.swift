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

    init(image: UIImage?, alpha: Double, isEnabled: Bool = true) {
        self.image = image
        self.alpha = alpha
        self.isEnabled = isEnabled
    }

    var body: some View {
        Group {
            if isEnabled, let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(GhostOverlayMath.clamp(alpha))
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
