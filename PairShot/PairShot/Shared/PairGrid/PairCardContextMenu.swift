import SwiftUI

struct PairCardActions {
    var onShare: (PhotoPair) -> Void
    var onExport: (PhotoPair) -> Void
    var onRequestRecapture: (PhotoPair) -> Void
    var onRequestPairDeletion: (PhotoPair) -> Void
}

struct PairCardContextMenu: ViewModifier {
    let pair: PhotoPair
    let isSelectionMode: Bool
    let actions: PairCardActions

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if !isSelectionMode {
                    if pair.afterPhotoLocalIdentifier != nil {
                        Button {
                            actions.onRequestRecapture(pair)
                        } label: {
                            Label(
                                String(localized: "pair_preview_menu_recapture"),
                                systemImage: "camera.rotate",
                            )
                        }
                    }
                    Button {
                        actions.onShare(pair)
                    } label: {
                        Label(
                            String(localized: "common_button_share"),
                            systemImage: "square.and.arrow.up",
                        )
                    }
                    Button {
                        actions.onExport(pair)
                    } label: {
                        Label(
                            String(localized: "common_button_save_to_device"),
                            systemImage: "square.and.arrow.down",
                        )
                    }
                    Button(role: .destructive) {
                        actions.onRequestPairDeletion(pair)
                    } label: {
                        Label(
                            String(localized: "common_button_delete"),
                            systemImage: "trash",
                        )
                    }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !isSelectionMode {
                    Button(role: .destructive) {
                        actions.onRequestPairDeletion(pair)
                    } label: {
                        Label(
                            String(localized: "common_button_delete"),
                            systemImage: "trash",
                        )
                    }
                }
            }
    }
}
