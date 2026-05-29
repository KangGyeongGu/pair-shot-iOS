import SwiftUI

struct PairCardActions {
    var onShare: (PhotoPair) -> Void
    var onExport: (PhotoPair) -> Void
    var onRequestAfterDeletion: (PhotoPair) -> Void
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
                    if pair.afterPhotoLocalIdentifier != nil {
                        Button(role: .destructive) {
                            actions.onRequestAfterDeletion(pair)
                        } label: {
                            Label(
                                String(localized: "pair_card_menu_delete_after"),
                                systemImage: "trash.slash",
                            )
                        }
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
