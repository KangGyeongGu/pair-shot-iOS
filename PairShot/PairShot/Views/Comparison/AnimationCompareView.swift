import ImageIO
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
            beforeImage = await Self.loadDownscaled(url: beforeURL)
        }
        .task(id: afterURL) {
            afterImage = await Self.loadDownscaled(url: afterURL)
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
