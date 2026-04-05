import SwiftUI

struct SideBySideView: View {
    let beforeURL: URL
    let afterURL: URL
    var injectedBeforeImage: UIImage?
    var injectedAfterImage: UIImage?

    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var pinchAnchor: UnitPoint = .center
    // M8: dynamic resolution — upgrades on zoom, downgrades on zoom-out
    @State private var currentMaxPixelSize: Int = 1600

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                imagePanel(image: beforeImage, size: geo.size)
                    // M8: task id encodes both url and resolution tier so reload fires on tier change
                    .task(id: "\(beforeURL)|\(currentMaxPixelSize)") {
                        if currentMaxPixelSize == 1600, let injected = injectedBeforeImage {
                            beforeImage = injected
                            return
                        }
                        let pixelSize = currentMaxPixelSize
                        let cgImage = await Task.detached(priority: .userInitiated) {
                            ImageThumbnailLoader.load(url: beforeURL, maxPixelSize: pixelSize)
                        }.value
                        if let cgImage { beforeImage = UIImage(cgImage: cgImage) }
                    }

                imagePanel(image: afterImage, size: geo.size)
                    .task(id: "\(afterURL)|\(currentMaxPixelSize)") {
                        if currentMaxPixelSize == 1600, let injected = injectedAfterImage {
                            afterImage = injected
                            return
                        }
                        let pixelSize = currentMaxPixelSize
                        let cgImage = await Task.detached(priority: .userInitiated) {
                            ImageThumbnailLoader.load(url: afterURL, maxPixelSize: pixelSize)
                        }.value
                        if let cgImage { afterImage = UIImage(cgImage: cgImage) }
                    }
            }
            .background(.black)
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(dragGesture(viewSize: geo.size))
            .onTapGesture(count: 2) {
                withAnimation {
                    zoomScale = 1.0
                    offset = .zero
                    lastScale = 1.0
                    lastOffset = .zero
                    pinchAnchor = .center
                    currentMaxPixelSize = 1600
                }
            }
            // Hysteresis: upgrade threshold > downgrade threshold to prevent tier flapping
            .onChange(of: zoomScale) { _, newScale in
                let target: Int
                if newScale >= 3.0 {
                    target = 4800
                } else if newScale <= 2.5, currentMaxPixelSize == 4800 {
                    target = 3200
                } else if newScale >= 2.0 {
                    target = max(currentMaxPixelSize, 3200)
                } else if newScale <= 1.5, currentMaxPixelSize > 1600 {
                    target = 1600
                } else {
                    return
                }
                if target != currentMaxPixelSize {
                    currentMaxPixelSize = target
                }
            }
        }
    }

    private func imagePanel(image: UIImage?, size: CGSize) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    // M6: anchor ensures both panels scale from pinch centre point
                    .scaleEffect(zoomScale, anchor: pinchAnchor)
                    .offset(offset)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: size.width / 2, height: size.height)
        .clipped()
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchAnchor == .center {
                    pinchAnchor = value.startAnchor
                }
                let newScale = lastScale * value.magnification
                zoomScale = min(max(newScale, 1.0), 4.0)
            }
            .onEnded { value in
                lastScale = min(max(lastScale * value.magnification, 1.0), 4.0)
                zoomScale = lastScale
                pinchAnchor = .center
            }
    }

    private func dragGesture(viewSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let panelWidth = viewSize.width / 2
                let panelHeight = viewSize.height
                let maxOffsetX = panelWidth * (zoomScale - 1) / 2
                let maxOffsetY = panelHeight * (zoomScale - 1) / 2
                let newX = lastOffset.width + value.translation.width
                let newY = lastOffset.height + value.translation.height
                offset = CGSize(
                    width: min(max(newX, -maxOffsetX), maxOffsetX),
                    height: min(max(newY, -maxOffsetY), maxOffsetY)
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
}
