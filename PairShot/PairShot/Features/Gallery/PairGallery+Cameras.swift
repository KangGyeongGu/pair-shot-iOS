import SwiftUI

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

struct PairGalleryCameraCovers: ViewModifier {
    let albumId: UUID?
    @Binding var showBeforeCamera: Bool
    @Binding var showAfterCamera: Bool

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showBeforeCamera) {
                NavigationStack {
                    BeforeCameraView(albumId: albumId)
                }
            }
            .fullScreenCover(isPresented: $showAfterCamera) {
                NavigationStack {
                    AfterCameraView(albumId: albumId)
                }
            }
    }
}

extension View {
    func pairGalleryCameraCovers(
        albumId: UUID?,
        showBeforeCamera: Binding<Bool>,
        showAfterCamera: Binding<Bool>
    ) -> some View {
        modifier(PairGalleryCameraCovers(
            albumId: albumId,
            showBeforeCamera: showBeforeCamera,
            showAfterCamera: showAfterCamera
        ))
    }
}
