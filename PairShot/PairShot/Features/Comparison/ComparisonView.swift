import Foundation
import SwiftData
import SwiftUI
import UIKit

/// P5.1 — fullscreen comparison modal.
///
/// Behaviour:
/// - Shows the Before/After of the active `PhotoPair` either as a 50/50
///   split (default) or as a full-image toggle (Before only / After only).
/// - Drag down → dismiss (matches the `.sheet` swipe affordance but explicit
///   so the gesture works edge-to-edge over the photos).
/// - Drag left/right → cycle to the previous / next pair in the *same
///   project*. Pager count "n / N" rendered in the top toolbar so users
///   can see traversal progress.
/// - Toolbar exposes the P5.2 composite menu (좌우 / 상하). Result writes
///   `pair.combinedPath` and the gallery cell flips its badge to 합성.
///
/// **Architecture invariant**: this is just two `Image(uiImage:)` views.
/// No homography, no pixel-level alignment, no auto color correction.
struct ComparisonView: View {
    /// All pairs in the project the user opened the comparison from. The
    /// view tracks the index locally so a delete/change in the underlying
    /// `@Query` doesn't yank the modal out from under the user mid-swipe.
    let pairs: [PhotoPair]
    @State var index: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var mode: ViewMode = .split
    @State private var dragOffset: CGSize = .zero
    @State private var compositeError: String?
    @State private var isCompositing = false

    private let storage: PhotoStorageService

    init(
        pairs: [PhotoPair],
        startIndex: Int,
        storage: PhotoStorageService = PhotoStorageService()
    ) {
        self.pairs = pairs
        _index = State(initialValue: max(0, min(startIndex, pairs.count - 1)))
        self.storage = storage
    }

    /// Toggle between split and full-image display. Tracked in `@State` so a
    /// single tap on the photo can flip it without touching the parent.
    enum ViewMode: String, Hashable, CaseIterable {
        case split
        case beforeOnly
        case afterOnly
    }

    private var currentPair: PhotoPair? {
        guard pairs.indices.contains(index) else { return nil }
        return pairs[index]
    }

    private var pagerLabel: String {
        guard !pairs.isEmpty else { return "" }
        return "\(index + 1) / \(pairs.count)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let pair = currentPair {
                    ComparisonImagePane(pair: pair, mode: mode, storage: storage)
                        .id(pair.id)
                        .offset(dragOffset)
                        .gesture(swipeGesture)
                        .onTapGesture { advanceMode() }
                } else {
                    emptyState
                }

                if isCompositing {
                    ProgressView(String(localized: "합성 중..."))
                        .controlSize(.large)
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle(pagerLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black.opacity(0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
            .alert(
                String(localized: "합성 실패"),
                isPresented: errorBinding,
                presenting: compositeError
            ) { _ in
                Button(String(localized: "확인"), role: .cancel) { compositeError = nil }
            } message: { message in
                Text(message)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(String(localized: "닫기"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            modePicker
        }
        ToolbarItem(placement: .topBarTrailing) {
            compositeMenu
        }
    }

    private var modePicker: some View {
        Picker(String(localized: "보기"), selection: $mode) {
            Image(systemName: "rectangle.split.2x1").tag(ViewMode.split)
            Image(systemName: "1.square").tag(ViewMode.beforeOnly)
            Image(systemName: "2.square").tag(ViewMode.afterOnly)
        }
        .pickerStyle(.segmented)
        .frame(width: 140)
    }

    private var compositeMenu: some View {
        Menu {
            ForEach(CompositeLayout.allCases) { layout in
                Button {
                    runComposite(layout: layout)
                } label: {
                    Label(layout.label, systemImage: layout.systemImage)
                }
            }
        } label: {
            Image(systemName: "square.on.square")
        }
        .disabled(currentPair?.afterPath == nil || isCompositing)
        .accessibilityLabel(String(localized: "합성"))
    }

    // MARK: - Empty / error

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))
            Text(String(localized: "비교할 사진이 없습니다"))
                .foregroundStyle(.white)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { compositeError != nil },
            set: { if !$0 { compositeError = nil } }
        )
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                // Vertical drag-down → dismiss. 120pt threshold matches the
                // standard `.sheet` swipe affordance.
                if vertical > 120, abs(vertical) > abs(horizontal) {
                    dismiss()
                    return
                }

                // Horizontal drag → step the pager. 80pt threshold is loose
                // enough that a confident flick triggers but a finger drift
                // doesn't.
                if abs(horizontal) > 80, abs(horizontal) > abs(vertical) {
                    if horizontal < 0 {
                        stepNext()
                    } else {
                        stepPrevious()
                    }
                }

                withAnimation(.spring(response: 0.3)) {
                    dragOffset = .zero
                }
            }
    }

    private func advanceMode() {
        let cases = ViewMode.allCases
        let currentIdx = cases.firstIndex(of: mode) ?? 0
        mode = cases[(currentIdx + 1) % cases.count]
    }

    private func stepNext() {
        guard !pairs.isEmpty else { return }
        index = min(index + 1, pairs.count - 1)
    }

    private func stepPrevious() {
        guard !pairs.isEmpty else { return }
        index = max(index - 1, 0)
    }

    // MARK: - Composite action

    private func runComposite(layout: CompositeLayout) {
        guard let pair = currentPair else { return }
        guard !isCompositing else { return }
        isCompositing = true
        let options = CompositeOptions(
            layout: layout,
            jpegQuality: CompositeOptions.default.jpegQuality,
            watermarkEnabled: WatermarkOverlay.isEnabled
        )
        Task { @MainActor in
            defer { isCompositing = false }
            do {
                _ = try CompositeRenderer.makeComposite(
                    for: pair,
                    options: options,
                    storage: storage,
                    in: modelContext
                )
            } catch {
                compositeError = errorMessage(for: error)
            }
        }
    }

    private func errorMessage(for error: Error) -> String {
        guard let renderError = error as? CompositeRenderer.RenderError else {
            return error.localizedDescription
        }
        return switch renderError {
            case .beforeImageMissing: String(localized: "Before 사진을 찾을 수 없습니다")
            case .afterImageMissing: String(localized: "After 사진을 찾을 수 없습니다")
            case .afterPathNotSet: String(localized: "After 촬영이 아직 완료되지 않았습니다")
            case .encodeFailed: String(localized: "JPEG 인코딩 실패")
            case .persistFailed: String(localized: "저장 실패")
        }
    }
}

/// Photo display pane (split or single). Extracted so `ComparisonView.body`
/// stays declarative.
private struct ComparisonImagePane: View {
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

#Preview {
    ComparisonView(pairs: [], startIndex: 0)
}
