import ImageIO
import SwiftUI

struct SliderCompareView: View {
    let beforeURL: URL
    let afterURL: URL

    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var sliderX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                imageView(afterImage)
                    .frame(width: geo.size.width, height: geo.size.height)

                imageView(beforeImage)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: sliderX)
                    }

                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .position(x: sliderX, y: geo.size.height / 2)

                Image(systemName: "arrow.left.and.right.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .background(.black.opacity(0.5), in: .circle)
                    .position(x: sliderX, y: geo.size.height / 2)
            }
            .background(.black)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        sliderX = min(max(value.location.x, 0), geo.size.width)
                    }
            )
            .onAppear {
                if sliderX == 0 {
                    sliderX = geo.size.width / 2
                }
            }
        }
        .task(id: beforeURL) {
            beforeImage = await loadDownscaled(url: beforeURL)
        }
        .task(id: afterURL) {
            afterImage = await loadDownscaled(url: afterURL)
        }
    }

    @ViewBuilder
    private func imageView(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ProgressView()
                .tint(.white)
        }
    }
}

private func loadDownscaled(url: URL) async -> UIImage? {
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
