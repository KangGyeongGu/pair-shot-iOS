import SwiftUI

struct AnimationCompareView: View {
    let beforeURL: URL
    let afterURL: URL
    var injectedBeforeImage: UIImage?
    var injectedAfterImage: UIImage?

    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var showingAfter = true

    var body: some View {
        ZStack {
            if let before = beforeImage {
                Image(uiImage: before)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .opacity(showingAfter ? 0 : 1)
            }

            if let after = afterImage {
                Image(uiImage: after)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .opacity(showingAfter ? 1 : 0)
            }

            if beforeImage == nil || afterImage == nil {
                ProgressView()
                    .tint(.white)
            }

            VStack {
                Spacer()
                Text("탭하여 Before/After 전환")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 16)
            }
        }
        .background(.black)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingAfter.toggle()
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
}
