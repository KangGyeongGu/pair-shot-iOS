import SwiftUI

struct HomeDeleteDialogs: ViewModifier {
    @Bindable var viewModel: HomeViewModel

    private var pairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPairDelete != nil },
            set: { if !$0 { viewModel.pendingPairDelete = nil } },
        )
    }

    private var albumDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingAlbumDelete != nil },
            set: { if !$0 { viewModel.pendingAlbumDelete = nil } },
        )
    }

    private var albumDestructiveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingAlbumDestructive != nil },
            set: { if !$0 { viewModel.pendingAlbumDestructive = nil } },
        )
    }

    private var singlePairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSinglePairDelete != nil },
            set: { if !$0 { viewModel.pendingSinglePairDelete = nil } },
        )
    }

    private var singleAlbumDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSingleAlbumDelete != nil },
            set: { if !$0 { viewModel.pendingSingleAlbumDelete = nil } },
        )
    }

    private var singleAlbumDestructiveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSingleAlbumDestructive != nil },
            set: { if !$0 { viewModel.pendingSingleAlbumDestructive = nil } },
        )
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: pairDeleteBinding,
                presenting: viewModel.pendingPairDelete,
            ) { request in
                pairDeleteButtons(request: request)
            } message: { request in
                Text(String(format: String(localized: "home_topbar_selection_count_int"), request.pairs.count))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: albumDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingAlbumDelete,
            ) { request in
                albumDeleteButtons(request: request)
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: albumDestructiveBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingAlbumDestructive,
            ) { request in
                albumDestructiveButtons(request: request)
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: singlePairDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSinglePairDelete,
            ) { request in
                singlePairDeleteButtons(request: request)
            } message: { _ in
                Text(String(localized: "dialog_delete_pair_message"))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: singleAlbumDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSingleAlbumDelete,
            ) { request in
                singleAlbumDeleteButtons(request: request)
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: singleAlbumDestructiveBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSingleAlbumDestructive,
            ) { request in
                singleAlbumDestructiveButtons(request: request)
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
    }

    @ViewBuilder
    private func pairDeleteButtons(request: HomePairDeleteRequest) -> some View {
        Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
            Task {
                await viewModel.confirmPairDeletion(pairs: request.pairs)
                viewModel.pendingPairDelete = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
            Task {
                await viewModel.confirmOriginalOnlyPairDeletion(pairs: request.pairs)
                viewModel.pendingPairDelete = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
            Task {
                await viewModel.confirmCombinedDeletion(pairs: request.pairs)
                viewModel.pendingPairDelete = nil
            }
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingPairDelete = nil
        }
    }

    @ViewBuilder
    private func albumDeleteButtons(request: HomeAlbumDeleteRequest) -> some View {
        Button(String(localized: "album_delete_method_button_album_only")) {
            Task {
                await viewModel.confirmAlbumDeletion(albums: request.albums)
                viewModel.pendingAlbumDelete = nil
            }
        }
        Button(String(localized: "album_delete_method_button_with_pairs"), role: .destructive) {
            viewModel.pendingAlbumDestructive = request
            viewModel.pendingAlbumDelete = nil
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingAlbumDelete = nil
        }
    }

    @ViewBuilder
    private func albumDestructiveButtons(request: HomeAlbumDeleteRequest) -> some View {
        Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
            Task {
                await viewModel.confirmAlbumDeletionAllPairs(albums: request.albums)
                viewModel.pendingAlbumDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
            Task {
                await viewModel.confirmAlbumDeletionOriginalOnly(albums: request.albums)
                viewModel.pendingAlbumDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
            Task {
                await viewModel.confirmAlbumDeletionCombinedOnly(albums: request.albums)
                viewModel.pendingAlbumDestructive = nil
            }
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingAlbumDestructive = nil
        }
    }

    @ViewBuilder
    private func singlePairDeleteButtons(request: HomeSinglePairDeleteRequest) -> some View {
        Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
            Task {
                await viewModel.confirmSinglePairDeletion(request.pair)
                viewModel.pendingSinglePairDelete = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
            Task {
                await viewModel.confirmSingleOriginalOnlyPairDeletion(request.pair)
                viewModel.pendingSinglePairDelete = nil
            }
        }
        if request.pair.hasCombinedExport {
            Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
                Task {
                    await viewModel.confirmSingleCombinedDeletion(request.pair)
                    viewModel.pendingSinglePairDelete = nil
                }
            }
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingSinglePairDelete = nil
        }
    }

    @ViewBuilder
    private func singleAlbumDeleteButtons(request: HomeSingleAlbumDeleteRequest) -> some View {
        Button(String(localized: "album_delete_method_button_album_only")) {
            Task {
                await viewModel.confirmSingleAlbumDeletion(request.album)
                viewModel.pendingSingleAlbumDelete = nil
            }
        }
        Button(String(localized: "album_delete_method_button_with_pairs"), role: .destructive) {
            viewModel.pendingSingleAlbumDestructive = request
            viewModel.pendingSingleAlbumDelete = nil
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingSingleAlbumDelete = nil
        }
    }

    @ViewBuilder
    private func singleAlbumDestructiveButtons(request: HomeSingleAlbumDeleteRequest) -> some View {
        Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
            Task {
                await viewModel.confirmSingleAlbumDeletionAllPairs(request.album)
                viewModel.pendingSingleAlbumDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
            Task {
                await viewModel.confirmSingleAlbumDeletionOriginalOnly(request.album)
                viewModel.pendingSingleAlbumDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
            Task {
                await viewModel.confirmSingleAlbumDeletionCombinedOnly(request.album)
                viewModel.pendingSingleAlbumDestructive = nil
            }
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingSingleAlbumDestructive = nil
        }
    }
}
