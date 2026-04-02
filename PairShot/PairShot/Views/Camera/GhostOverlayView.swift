import SwiftUI
import UIKit

struct GhostOverlayView: View {
    let beforeImage: UIImage?
    @Binding var opacity: Double

    var body: some View {
        if let image = beforeImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(opacity)
                .allowsHitTesting(false)
        }
    }
}

extension UIImage {
    func downscaledTo1080p() -> UIImage {
        let maxDimension: CGFloat = 1920
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        guard scale < 1.0 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
