import SwiftUI

struct HomePairContextMenu: ViewModifier {
    let viewModel: HomeViewModel
    let pair: PhotoPair

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if !viewModel.isSelectionMode {
                    if pair.afterPhotoLocalIdentifier != nil {
                        Button {
                            viewModel.requestRecaptureAfter(pair)
                        } label: {
                            Label(
                                String(localized: "pair_preview_menu_recapture"),
                                systemImage: "camera.rotate",
                            )
                        }
                    }
                    Button {
                        Task { await viewModel.sharePair(pair) }
                    } label: {
                        Label(
                            String(localized: "common_button_share"),
                            systemImage: "square.and.arrow.up",
                        )
                    }
                    Button {
                        Task { await viewModel.exportPair(pair) }
                    } label: {
                        Label(
                            String(localized: "common_button_save_to_device"),
                            systemImage: "square.and.arrow.down",
                        )
                    }
                    Button(role: .destructive) {
                        viewModel.requestSinglePairDeletion(pair)
                    } label: {
                        Label(String(localized: "common_button_delete"), systemImage: "trash")
                    }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !viewModel.isSelectionMode {
                    Button(role: .destructive) {
                        viewModel.requestSinglePairDeletion(pair)
                    } label: {
                        Label(String(localized: "common_button_delete"), systemImage: "trash")
                    }
                }
            }
    }
}
