import Foundation
import SwiftData
import SwiftUI
import UIKit

struct CompositeMenu: View {
    let defaultLayout: CompositeLayout
    let isDisabled: Bool
    let onSelect: (CompositeLayout) -> Void

    var body: some View {
        Menu {
            ForEach(orderedLayouts) { layout in
                Button {
                    onSelect(layout)
                } label: {
                    Label(label(for: layout), systemImage: layout.systemImage)
                }
            }
        } label: {
            Image(systemName: "square.on.square")
        }
        .disabled(isDisabled)
        .accessibilityLabel(String(localized: "합성"))
    }

    private var orderedLayouts: [CompositeLayout] {
        let rest = CompositeLayout.allCases.filter { $0 != defaultLayout }
        return [defaultLayout] + rest
    }

    private func label(for layout: CompositeLayout) -> String {
        if layout == defaultLayout {
            return String(format: String(localized: "%@ (기본)"), layout.label)
        }
        return layout.label
    }
}

struct ComparisonImagePane: View {
    let pair: PhotoPair
    let mode: ComparisonView.ViewMode
    let storage: PhotoStorageService

    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?

    var body: some View {
        Group {
            switch mode {
                case .split:
                    splitView

                case .beforeOnly:
                    singleImage(beforeImage, label: String(localized: "Before"))

                case .afterOnly:
                    singleImage(afterImage, label: String(localized: "After"))
            }
        }
        .task(id: pair.id) {
            await loadImages()
        }
    }

    private var splitView: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                imageOrPlaceholder(beforeImage, label: String(localized: "Before"))
                    .frame(width: geometry.size.width / 2)
                imageOrPlaceholder(afterImage, label: String(localized: "After"))
                    .frame(width: geometry.size.width / 2)
            }
            .background(Color.black)
        }
    }

    private func singleImage(_ image: UIImage?, label: String) -> some View {
        ZStack(alignment: .topLeading) {
            imageOrPlaceholder(image, label: label)
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.55)))
                .foregroundStyle(.white)
                .padding(12)
        }
    }

    @ViewBuilder
    private func imageOrPlaceholder(_ image: UIImage?, label: String) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack {
                Color.gray.opacity(0.2)
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.title)
                        .imageScale(.large)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(label).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private func loadImages() async {
        let beforeFileName = pair.beforeFileName
        let afterFileName = pair.afterFileName
        let storage = storage
        let loaded = await Task.detached(priority: .userInitiated) {
            (
                ComparisonImageLoader.load(kind: .before, fileName: beforeFileName, storage: storage),
                afterFileName.flatMap { name in
                    ComparisonImageLoader.load(kind: .after, fileName: name, storage: storage)
                }
            )
        }.value
        beforeImage = loaded.0
        afterImage = loaded.1
    }
}

enum ComparisonImageLoader {
    static func load(
        kind: PhotoStorageService.PhotoKind,
        fileName: String,
        storage: PhotoStorageService
    ) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        guard let url = storage.resolve(kind: kind, fileName: fileName) else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

enum ComparisonPager {
    static func next(index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(index + 1, count - 1)
    }

    static func previous(index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return max(index - 1, 0)
    }

    static func label(index: Int, count: Int) -> String {
        guard count > 0 else { return "" }
        let bounded = max(0, min(index, count - 1))
        return "\(bounded + 1) / \(count)"
    }
}
