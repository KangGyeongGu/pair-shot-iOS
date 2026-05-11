import SwiftUI

struct AlbumDetailDefaultToolbar: ToolbarContent {
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    onSelect()
                } label: {
                    Label(
                        String(localized: "home_desc_selection_mode"),
                        systemImage: "checkmark.circle"
                    )
                }

                Button {
                    onRename()
                } label: {
                    Label(String(localized: "common_button_rename"), systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(String(localized: "common_button_delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(String(localized: "common_desc_more"))
        }
    }
}

struct AlbumDetailSelectionToolbar: ToolbarContent {
    let selectionCount: Int
    let allSelected: Bool
    let onCancel: () -> Void
    let onToggleSelectAll: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(String(localized: "home_desc_deselect"))
        }
        ToolbarItem(placement: .principal) {
            Text(String(format: String(localized: "pair_picker_selection_count_template"), selectionCount))
                .font(.headline)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onToggleSelectAll) {
                Text(
                    allSelected
                        ? String(localized: "home_button_deselect_all")
                        : String(localized: "home_button_select_all")
                )
            }
        }
    }
}

struct AlbumDetailRenameAlert: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel
    let album: Album

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "album_dialog_rename_title"),
                isPresented: $viewModel.showRenameAlert
            ) {
                TextField(String(localized: "album_dialog_rename_placeholder"), text: $viewModel.renameDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                Button(String(localized: "common_button_save")) {
                    Task { await viewModel.confirmRename(album: album) }
                }
                .disabled(viewModel.renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(String(localized: "common_button_cancel"), role: .cancel) {}
            }
    }
}

struct AlbumDetailDeleteAlbumAlert: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: albumDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingAlbumDelete
            ) { album in
                Button(String(localized: "album_delete_method_button_album_only")) {
                    Task {
                        await viewModel.confirmAlbumDeletion()
                        viewModel.pendingAlbumDelete = nil
                    }
                }
                Button(String(localized: "album_delete_method_button_with_pairs"), role: .destructive) {
                    viewModel.pendingAlbumDestructive = album
                    viewModel.pendingAlbumDelete = nil
                }
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.pendingAlbumDelete = nil
                }
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: albumDestructiveBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingAlbumDestructive
            ) { album in
                Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
                    Task {
                        await viewModel.confirmAlbumDeletionAllPairs(album: album)
                        viewModel.pendingAlbumDestructive = nil
                    }
                }
                Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
                    Task {
                        await viewModel.confirmAlbumDeletionOriginalOnly(album: album)
                        viewModel.pendingAlbumDestructive = nil
                    }
                }
                Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
                    Task {
                        await viewModel.confirmAlbumDeletionCombinedOnly(album: album)
                        viewModel.pendingAlbumDestructive = nil
                    }
                }
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.pendingAlbumDestructive = nil
                }
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
    }

    private var albumDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingAlbumDelete != nil },
            set: { if !$0 { viewModel.pendingAlbumDelete = nil } }
        )
    }

    private var albumDestructiveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingAlbumDestructive != nil },
            set: { if !$0 { viewModel.pendingAlbumDestructive = nil } }
        )
    }
}
