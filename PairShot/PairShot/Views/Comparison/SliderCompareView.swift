import SwiftUI

struct SliderCompareView: View {
    let beforeURL: URL
    let afterURL: URL
    var injectedBeforeImage: UIImage?
    var injectedAfterImage: UIImage?

    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var sliderX: CGFloat?
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    /// Captures sliderX at the moment a handle drag begins; nil means use current sliderX as base
    @GestureState private var handleDragStartX: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let currentSliderX = sliderX ?? geo.size.width / 2
            ZStack {
                imageView(afterImage)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .scaleEffect(zoomScale)
                    .offset(offset)

                imageView(beforeImage)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .scaleEffect(zoomScale)
                    .offset(offset)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: currentSliderX)
                    }

                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .position(x: currentSliderX, y: geo.size.height / 2)

                // Enlarged hit area — only this controls sliderX
                Color.clear
                    .frame(width: 44, height: 88)
                    .overlay(
                        Image(systemName: "arrow.left.and.right.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .background(.black.opacity(0.5), in: .circle)
                    )
                    .position(x: currentSliderX, y: geo.size.height / 2)
                    .gesture(handleDragGesture(viewWidth: geo.size.width, currentSliderX: currentSliderX))
            }
            .background(.black)
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(panGesture(viewSize: geo.size))
            .onTapGesture(count: 2) {
                withAnimation {
                    zoomScale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
            .onAppear {
                if sliderX == nil {
                    sliderX = geo.size.width / 2
                }
            }
        }
        .task(id: beforeURL) {
            if let injected = injectedBeforeImage {
                beforeImage = injected
                return
            }
            beforeImage = nil
            let cgImage = await Task.detached(priority: .userInitiated) {
                ImageThumbnailLoader.load(url: beforeURL)
            }.value
            beforeImage = cgImage.map { UIImage(cgImage: $0) }
        }
        .task(id: afterURL) {
            if let injected = injectedAfterImage {
                afterImage = injected
                return
            }
            afterImage = nil
            let cgImage = await Task.detached(priority: .userInitiated) {
                ImageThumbnailLoader.load(url: afterURL)
            }.value
            afterImage = cgImage.map { UIImage(cgImage: $0) }
        }
    }

    @ViewBuilder
    private func imageView(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    private func handleDragGesture(viewWidth: CGFloat, currentSliderX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($handleDragStartX) { _, state, _ in
                if state == nil { state = currentSliderX }
            }
            .onChanged { value in
                let base = handleDragStartX ?? currentSliderX
                let proposed = base + value.translation.width
                sliderX = min(max(proposed, 0), viewWidth)
            }
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

    private func panGesture(viewSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard zoomScale > 1.0 else { return }
                let maxOffsetX = viewSize.width * (zoomScale - 1) / 2
                let maxOffsetY = viewSize.height * (zoomScale - 1) / 2
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
