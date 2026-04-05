import SwiftUI

struct SliderCompareView: View {
    let beforeURL: URL
    let afterURL: URL

    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var sliderX: CGFloat = 0
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
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
                SimultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            sliderX = min(max(value.location.x, 0), geo.size.width)
                        },
                    MagnifyGesture()
                        .onChanged { value in
                            let newScale = lastScale * value.magnification
                            zoomScale = min(max(newScale, 1.0), 4.0)
                        }
                        .onEnded { value in
                            lastScale = min(max(lastScale * value.magnification, 1.0), 4.0)
                            zoomScale = lastScale
                        }
                )
            )
            .onAppear {
                if sliderX == 0 {
                    sliderX = geo.size.width / 2
                }
            }
        }
        .task(id: beforeURL) {
            beforeImage = nil
            beforeImage = await ImageThumbnailLoader.loadUIImage(url: beforeURL)
        }
        .task(id: afterURL) {
            afterImage = nil
            afterImage = await ImageThumbnailLoader.loadUIImage(url: afterURL)
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
}
