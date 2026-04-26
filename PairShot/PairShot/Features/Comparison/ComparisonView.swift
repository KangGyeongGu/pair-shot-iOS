import Foundation
import SwiftData
import SwiftUI
import UIKit

/// P5.1 — fullscreen comparison modal. Drag-down → dismiss, drag-left/right
/// → pager. Toolbar exposes the P5.2 composite menu. Two `Image(uiImage:)`
/// views — no homography, no pixel-level alignment, no auto color correction.
/// Supporting types (`CompositeMenu`, `ComparisonImagePane`,
/// `ComparisonImageLoader`, `ComparisonPager`) live in ``CompositeMenu.swift``.
struct ComparisonView: View {
    /// All pairs in the project the user opened the comparison from. The
    /// view tracks the index locally so a delete/change in the underlying
    /// `@Query` doesn't yank the modal out from under the user mid-swipe.
    let pairs: [PhotoPair]
    @State var index: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // P6c — interstitial firing on composite-result dismissal. The
    // managers are AdFree-aware internally, so the call sites below
    // don't need to guard.
    @Environment(InterstitialAdManager.self) private var interstitialManager
    @Environment(\.fullscreenAdCoordinator) private var coordinator
    @Environment(AdFreeStore.self) private var adFreeStore
    @Environment(AppSettings.self) private var appSettings
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
        ComparisonPager.label(index: index, count: pairs.count)
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
            CompositeMenu(
                defaultLayout: appSettings.defaultCompositeLayout,
                isDisabled: currentPair?.afterPath == nil || isCompositing,
                onSelect: { layout in runComposite(layout: layout) }
            )
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

    // MARK: - Empty / error

    private var emptyState: some View {
        VStack(spacing: 12) {
            // Audit-C — replace fixed-size system font with a Dynamic-Type
            // friendly text style + scaled image so the icon scales for
            // accessibility text sizes.
            Image(systemName: "photo.on.rectangle")
                .font(.largeTitle)
                .imageScale(.large)
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
                        index = ComparisonPager.next(index: index, count: pairs.count)
                    } else {
                        index = ComparisonPager.previous(index: index, count: pairs.count)
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

    // MARK: - Composite action

    private func runComposite(layout: CompositeLayout) {
        guard let pair = currentPair, !isCompositing else { return }
        isCompositing = true
        let options = CompositeOptions(
            layout: layout,
            jpegQuality: CGFloat(appSettings.jpegQuality),
            watermarkEnabled: WatermarkOverlay.isEnabled
        )
        let prefix = FileNamePrefixValidator.sanitize(appSettings.fileNamePrefix)
        Task { @MainActor in
            defer { isCompositing = false }
            do {
                _ = try CompositeRenderer.makeComposite(
                    for: pair,
                    options: options,
                    storage: storage,
                    fileNamePrefix: prefix,
                    in: modelContext
                )
                // P9.1 — haptic before the interstitial fires.
                HapticService.shared.notify(.success)
                // Composite success = "natural transition" → try interstitial.
                // Manager handles AdFree + 5-min cap internally.
                await interstitialManager.presentIfReady(
                    from: BannerAdView.resolveRootViewController(),
                    coordinator: coordinator,
                    adFreeStore: adFreeStore
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
