import SwiftUI

struct AnimationCompareView: View {
    let beforeURL: URL
    let afterURL: URL

    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var showingAfter = true

    var body: some View {
        ZStack {
            if let before = beforeImage {
                Image(uiImage: before)
                    .resizable()
                    .scaledToFit()
                    .opacity(showingAfter ? 0 : 1)
            }

            if let after = afterImage {
                Image(uiImage: after)
                    .resizable()
                    .scaledToFit()
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
            beforeImage = nil
            beforeImage = await ImageThumbnailLoader.loadUIImage(url: beforeURL)
        }
        .task(id: afterURL) {
            afterImage = nil
            afterImage = await ImageThumbnailLoader.loadUIImage(url: afterURL)
        }
    }
}
