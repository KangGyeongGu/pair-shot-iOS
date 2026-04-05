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
    // M8: dynamic resolution — upgrades on zoom, downgrades on zoom-out
    @State private var currentMaxPixelSize: Int = 1600

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                imagePanel(image: beforeImage, size: geo.size)
                    // M8: task id encodes both url and resolution tier so reload fires on tier change
                    .task(id: "\(beforeURL)|\(currentMaxPixelSize)") {
                        let loaded = await ImageThumbnailLoader.loadUIImage(
                            url: beforeURL,
                            maxPixelSize: currentMaxPixelSize
                        )
                        if let loaded { beforeImage = loaded }
                    }

                imagePanel(image: afterImage, size: geo.size)
                    .task(id: "\(afterURL)|\(currentMaxPixelSize)") {
                        let loaded = await ImageThumbnailLoader.loadUIImage(
                            url: afterURL,
                            maxPixelSize: currentMaxPixelSize
                        )
                        if let loaded { afterImage = loaded }
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
                }
            }
            // M8: promote/demote resolution tier based on zoom level
            .onChange(of: zoomScale) { _, newScale in
                let tier = if newScale > 3.0 {
                    4800
                } else if newScale > 2.0 {
                    3200
                } else {
                    1600
                }
                if tier != currentMaxPixelSize {
                    currentMaxPixelSize = tier
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
                    // M6: anchor .center ensures both panels scale from the same normalised centre point;
                    // equal-width frames + .fill means the same (u,v) region is visible on both sides.
                    .scaleEffect(zoomScale, anchor: .center)
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
                let newScale = lastScale * value.magnification
                zoomScale = min(max(newScale, 1.0), 4.0)
            }
            .onEnded { value in
                lastScale = min(max(lastScale * value.magnification, 1.0), 4.0)
                zoomScale = lastScale
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
