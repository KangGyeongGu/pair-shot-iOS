import SwiftUI

/// One slot in the gallery grid — either a real `PhotoPair` or a
/// native-ad token vended by `NativeAdLoader`. Pulled out of the view so
/// `NativeAdInsertionStrategy` can build the slot list as a pure
/// transform unit-testable on its own.
enum GalleryItem: Identifiable {
    case pair(PhotoPair)
    case nativeAd(id: Int, ad: Any?)

    var id: AnyHashable {
        switch self {
            case let .pair(pair): pair.id
            case let .nativeAd(slotID, _): "ad-\(slotID)"
        }
    }
}

/// Pure helper that interleaves ``PhotoPair`` rows with native-ad slots
/// using ``NativeAdInsertionStrategy`` for the position decisions.
/// AdFree / selection mode short-circuit to a plain pair list.
enum GalleryItemBuilder {
    static func build(
        pairs: [PhotoPair],
        suppressAds: Bool,
        adProvider: (Int) -> Any?
    ) -> [GalleryItem] {
        guard !suppressAds else {
            return pairs.map(GalleryItem.pair)
        }
        let adIndices = Set(NativeAdInsertionStrategy.indices(forPairCount: pairs.count))
        var items: [GalleryItem] = []
        items.reserveCapacity(pairs.count + adIndices.count)
        for (offset, pair) in pairs.enumerated() {
            items.append(.pair(pair))
            if adIndices.contains(offset) {
                items.append(.nativeAd(id: offset, ad: adProvider(offset)))
            }
        }
        return items
    }
}

/// Audit-D — toolbar and full-screen camera-cover wiring extracted from
/// ``PairGalleryView`` so the parent file stays under the 250-line cap
/// from `.claude/refs/swiftui-patterns.md`.
///
/// ``PairGalleryToolbar`` is the `ToolbarContent` builder for the
/// gallery's "Before 촬영" entry point. Disabled during multi-select so
/// the trash/share affordances are unambiguous.
struct PairGalleryToolbar: ToolbarContent {
    let isSelectionMode: Bool
    let onBeforeCamera: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                onBeforeCamera()
            } label: {
                Label(String(localized: "Before 촬영"), systemImage: "camera")
            }
            .disabled(isSelectionMode)
        }
    }
}

/// ``PairGalleryCameraCovers`` is a `ViewModifier` that owns the two
/// `.fullScreenCover` entry points the gallery exposes:
///
/// - `showBeforeCamera` — toolbar "Before 촬영" button → fresh
///   `BeforeCameraView` for the project. Once the user dismisses, the
///   gallery `@Query` re-renders with any newly inserted pair.
/// - `showAfterCamera` — tapping a `pendingAfter` cell → `AfterCameraView`
///   which auto-loads the oldest pending pair (P3.1) and dismisses when
///   none remain (P3.4). No specific pair is threaded in.
///
/// Both covers wrap their content in a `NavigationStack` so the inner
/// view can use `@Environment(\.dismiss)` and `Toolbar` placement
/// consistently.
struct PairGalleryCameraCovers: ViewModifier {
    let project: Project
    @Binding var showBeforeCamera: Bool
    @Binding var showAfterCamera: Bool

    func body(content: Content) -> some View {
        content
            // Audit-A — Before camera entry from the toolbar button. The
            // camera view dismisses itself on close via `@Environment(\.dismiss)`.
            .fullScreenCover(isPresented: $showBeforeCamera) {
                NavigationStack {
                    BeforeCameraView(project: project)
                }
            }
            // Audit-A — After camera entry triggered by tapping a
            // `pendingAfter` cell. `AfterCameraView` auto-loads the oldest
            // pending pair on appear (P3.1) and dismisses when none remain
            // (P3.4), so we don't need to thread a specific pair in here.
            .fullScreenCover(isPresented: $showAfterCamera) {
                NavigationStack {
                    AfterCameraView(project: project)
                }
            }
    }
}

extension View {
    /// Apply the gallery's two `.fullScreenCover` entry points (Audit-D).
    func pairGalleryCameraCovers(
        project: Project,
        showBeforeCamera: Binding<Bool>,
        showAfterCamera: Binding<Bool>
    ) -> some View {
        modifier(PairGalleryCameraCovers(
            project: project,
            showBeforeCamera: showBeforeCamera,
            showAfterCamera: showAfterCamera
        ))
    }
}
