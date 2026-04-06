import SwiftUI

struct AnimationCompareView: View {
    let beforeURL: URL
    let afterURL: URL
    let alignedAfterURL: URL?

    enum DisplayMode: String, CaseIterable {
        case before, afterOriginal, afterAligned
        var label: String {
            switch self {
                case .before: "Before"
                case .afterOriginal: "After(원본)"
                case .afterAligned: "After(보정)"
            }
        }
    }

    @State private var mode: DisplayMode = .before
    @State private var beforeImage: UIImage?
    @State private var afterOriginalImage: UIImage?
    @State private var afterAlignedImage: UIImage?

    private var currentImage: UIImage? {
        switch mode {
            case .before: beforeImage
            case .afterOriginal: afterOriginalImage
            case .afterAligned: afterAlignedImage ?? afterOriginalImage
        }
    }

    var body: some View {
        ZStack {
            if let image = currentImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(.white)
            }

            VStack {
                Text(mode.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.top, 12)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(availableModes, id: \.rawValue) { m in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { mode = m }
                        } label: {
                            Text(m.label)
                                .font(.system(size: 12, weight: mode == m ? .bold : .regular))
                                .foregroundStyle(mode == m ? .yellow : .white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(mode == m ? Color.white.opacity(0.15) : .clear, in: Capsule())
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(.black)
        .contentShape(Rectangle())
        .onTapGesture {
            let modes = availableModes
            guard let idx = modes.firstIndex(of: mode) else { return }
            let next = modes[(idx + 1) % modes.count]
            withAnimation(.easeInOut(duration: 0.3)) { mode = next }
        }
        .task(id: "before|\(beforeURL)") {
            beforeImage = await loadImage(url: beforeURL)
        }
        .task(id: "afterOrig|\(afterURL)") {
            afterOriginalImage = await loadImage(url: afterURL)
        }
        .task(id: "afterAligned|\(alignedAfterURL?.absoluteString ?? "nil")") {
            guard let url = alignedAfterURL else {
                afterAlignedImage = nil
                return
            }
            afterAlignedImage = await loadImage(url: url)
        }
    }

    private var availableModes: [DisplayMode] {
        if alignedAfterURL != nil {
            return DisplayMode.allCases
        }
        return [.before, .afterOriginal]
    }

    private func loadImage(url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let cg = ImageThumbnailLoader.load(url: url, maxPixelSize: 2000) else { return nil }
            return UIImage(cgImage: cg)
        }.value
    }
}
