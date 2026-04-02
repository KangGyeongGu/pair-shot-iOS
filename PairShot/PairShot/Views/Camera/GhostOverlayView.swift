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

struct GhostOpacitySlider: View {
    @Binding var opacity: Double
    let onChanged: (Double) -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "eye.slash")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.system(size: 12))
                Slider(value: $opacity, in: 0 ... 0.7)
                    .tint(.white.opacity(0.7))
                Text("\(Int(opacity * 100))%")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 32)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.5), in: Capsule())
            .padding(.horizontal, 40)
            .padding(.bottom, 16)
        }
        .allowsHitTesting(true)
        .onChange(of: opacity) { _, newValue in
            if newValue > 0 { onChanged(newValue) }
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
