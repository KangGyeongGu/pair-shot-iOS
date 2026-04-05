import ImageIO
import SwiftUI

struct SideBySideView: View {
    let beforeURL: URL
    let afterURL: URL

    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        HStack(spacing: 0) {
            imagePanel(image: beforeImage)
                .task(id: beforeURL) {
                    beforeImage = nil
                    beforeImage = await Self.loadDownscaled(url: beforeURL)
                }

            imagePanel(image: afterImage)
                .task(id: afterURL) {
                    afterImage = nil
                    afterImage = await Self.loadDownscaled(url: afterURL)
                }
        }
        .background(.black)
        .simultaneousGesture(magnifyGesture)
        .simultaneousGesture(dragGesture)
        .onTapGesture(count: 2) {
            withAnimation {
                zoomScale = 1.0
                offset = .zero
                lastScale = 1.0
                lastOffset = .zero
            }
        }
    }

    private func imagePanel(image: UIImage?) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomScale)
                    .offset(offset)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomScale = max(1.0, lastScale * value.magnification)
            }
            .onEnded { value in
                lastScale = max(1.0, lastScale * value.magnification)
                zoomScale = lastScale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private static func loadDownscaled(url: URL) async -> UIImage? {
        guard url.isFileURL else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: 1600,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }.value
    }
}
