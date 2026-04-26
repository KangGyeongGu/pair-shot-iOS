import Foundation
import SwiftData
import SwiftUI
import UIKit

// P10b — extracted from `ComparisonView.swift` to keep that view
// under the 250-line cap. The pieces here are display-only and have no
// state of their own beyond what the parent passes in.

/// Menu surface for triggering the composite render. Reorders the
/// available layouts so the user's stored default appears first
/// (mirrors the iOS Menu "default action" affordance).
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

    /// Reorder so the stored default appears first — matches iOS'
    /// expectation that a `Menu`'s top item is the canonical action.
    private var orderedLayouts: [CompositeLayout] {
        let rest = CompositeLayout.allCases.filter { $0 != defaultLayout }
        return [defaultLayout] + rest
    }

    /// Append "(기본)" to the default layout's label for both screen
    /// reader and visual hierarchy.
    private func label(for layout: CompositeLayout) -> String {
        if layout == defaultLayout {
            return String(format: String(localized: "%@ (기본)"), layout.label)
        }
        return layout.label
    }
}

/// Photo display pane (split or single). Split lays Before / After 50/50
/// with a 1pt black gutter; single shows one image full-bleed with a
/// "Before" / "After" caption.
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
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(label).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private func loadImages() async {
        let beforePath = pair.beforePath
        let afterPath = pair.afterPath
        let storage = storage
        let loaded = await Task.detached(priority: .userInitiated) {
            (
                ComparisonImageLoader.load(relativePath: beforePath, storage: storage),
                afterPath.flatMap { path in
                    ComparisonImageLoader.load(relativePath: path, storage: storage)
                }
            )
        }.value
        beforeImage = loaded.0
        afterImage = loaded.1
    }
}

/// Pure helper extracted so the load path is testable without spinning up
/// SwiftUI. Mirrors `GhostOverlayLoader` but exposed at the module boundary
/// for `ComparisonImagePane` reuse.
enum ComparisonImageLoader {
    static func load(relativePath: String, storage: PhotoStorageService) -> UIImage? {
        guard !relativePath.isEmpty else { return nil }
        guard let url = storage.resolve(relativePath: relativePath) else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

/// Pure pager arithmetic. Extracted so the swipe-traversal logic can be
/// asserted without driving a real `DragGesture`.
enum ComparisonPager {
    /// Step the index forward, clamped to the last valid pair.
    static func next(index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(index + 1, count - 1)
    }

    /// Step the index backward, clamped to 0.
    static func previous(index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return max(index - 1, 0)
    }

    /// "n / N" label. Empty string when `count == 0` so the toolbar collapses
    /// gracefully.
    static func label(index: Int, count: Int) -> String {
        guard count > 0 else { return "" }
        let bounded = max(0, min(index, count - 1))
        return "\(bounded + 1) / \(count)"
    }
}
