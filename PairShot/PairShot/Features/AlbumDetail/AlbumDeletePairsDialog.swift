import SwiftUI

struct AlbumDeletePairsDialog: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: pairDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingPairDelete
            ) { request in
                Button(String(localized: "album_button_remove_from_album")) {
                    Task {
                        await viewModel.removeFromAlbum(pairs: request.pairs)
                        viewModel.pendingPairDelete = nil
                    }
                }
                Button(String(localized: "album_delete_method_button_all"), role: .destructive) {
                    Task {
                        await viewModel.confirmPairDeletion(mode: .wholePair, pairs: request.pairs)
                        viewModel.pendingPairDelete = nil
                    }
                }
                if viewModel.hasCombined(in: request.pairs) {
                    Button(String(localized: "album_delete_method_button_combined_only")) {
                        Task {
                            await viewModel.confirmPairDeletion(mode: .combinedOnly, pairs: request.pairs)
                            viewModel.pendingPairDelete = nil
                        }
                    }
                }
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.pendingPairDelete = nil
                }
            } message: { request in
                Text(String(format: String(localized: "album_dialog_delete_pairs_count"), request.pairs.count))
            }
            .alert(
                String(localized: "dialog_delete_pair_title"),
                isPresented: singlePairDeleteBinding,
                presenting: viewModel.pendingSinglePairDelete
            ) { request in
                Button(String(localized: "common_button_delete"), role: .destructive) {
                    Task {
                        await viewModel.confirmSinglePairDeletion(request.pair)
                        viewModel.pendingSinglePairDelete = nil
                    }
                }
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.pendingSinglePairDelete = nil
                }
            } message: { _ in
                Text(String(localized: "dialog_delete_pair_message"))
            }
    }

    private var pairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPairDelete != nil },
            set: { if !$0 { viewModel.pendingPairDelete = nil } }
        )
    }

    private var singlePairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSinglePairDelete != nil },
            set: { if !$0 { viewModel.pendingSinglePairDelete = nil } }
        )
    }
}
