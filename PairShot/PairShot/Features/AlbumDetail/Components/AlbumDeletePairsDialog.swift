import SwiftUI

struct AlbumDeletePairsDialog: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    private var pairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPairDelete != nil },
            set: { if !$0 { viewModel.pendingPairDelete = nil } }
        )
    }

    private var pairDestructiveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPairDestructive != nil },
            set: { if !$0 { viewModel.pendingPairDestructive = nil } }
        )
    }

    private var singlePairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSinglePairDelete != nil },
            set: { if !$0 { viewModel.pendingSinglePairDelete = nil } }
        )
    }

    private var singlePairDestructiveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSinglePairDestructive != nil },
            set: { if !$0 { viewModel.pendingSinglePairDestructive = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: pairDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingPairDelete
            ) { request in
                pairDeleteButtons(request: request)
            } message: { request in
                Text(String(format: String(localized: "album_dialog_delete_pairs_count"), request.pairs.count))
            }
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: pairDestructiveBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingPairDestructive
            ) { request in
                pairDestructiveButtons(request: request)
            } message: { request in
                Text(String(format: String(localized: "album_dialog_delete_pairs_count"), request.pairs.count))
            }
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: singlePairDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSinglePairDelete
            ) { request in
                singlePairDeleteButtons(request: request)
            } message: { _ in
                Text(String(localized: "dialog_delete_pair_message"))
            }
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: singlePairDestructiveBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSinglePairDestructive
            ) { request in
                singlePairDestructiveButtons(request: request)
            } message: { _ in
                Text(String(localized: "dialog_delete_pair_message"))
            }
    }

    @ViewBuilder
    private func pairDeleteButtons(request: AlbumDetailPairDeleteRequest) -> some View {
        Button(String(localized: "album_button_remove_from_album")) {
            Task {
                await viewModel.removeFromAlbum(pairs: request.pairs)
                viewModel.pendingPairDelete = nil
            }
        }
        Button(String(localized: "album_delete_method_button_all"), role: .destructive) {
            viewModel.pendingPairDestructive = request
            viewModel.pendingPairDelete = nil
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingPairDelete = nil
        }
    }

    @ViewBuilder
    private func pairDestructiveButtons(request: AlbumDetailPairDeleteRequest) -> some View {
        Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
            Task {
                await viewModel.confirmPairDeletion(pairs: request.pairs)
                viewModel.pendingPairDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
            Task {
                await viewModel.confirmOriginalOnlyDeletion(pairs: request.pairs)
                viewModel.pendingPairDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
            Task {
                await viewModel.confirmCombinedDeletion(pairs: request.pairs)
                viewModel.pendingPairDestructive = nil
            }
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingPairDestructive = nil
        }
    }

    @ViewBuilder
    private func singlePairDeleteButtons(request: AlbumDetailSinglePairDeleteRequest) -> some View {
        Button(String(localized: "album_button_remove_from_album")) {
            Task {
                await viewModel.removeFromAlbum(pairs: [request.pair])
                viewModel.pendingSinglePairDelete = nil
            }
        }
        Button(String(localized: "album_delete_method_button_all"), role: .destructive) {
            viewModel.pendingSinglePairDestructive = request
            viewModel.pendingSinglePairDelete = nil
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingSinglePairDelete = nil
        }
    }

    @ViewBuilder
    private func singlePairDestructiveButtons(request: AlbumDetailSinglePairDeleteRequest) -> some View {
        Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
            Task {
                await viewModel.confirmSinglePairDeletion(request.pair)
                viewModel.pendingSinglePairDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
            Task {
                await viewModel.confirmSingleOriginalOnlyDeletion(request.pair)
                viewModel.pendingSinglePairDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
            Task {
                await viewModel.confirmSingleCombinedDeletion(request.pair)
                viewModel.pendingSinglePairDestructive = nil
            }
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingSinglePairDestructive = nil
        }
    }
}
