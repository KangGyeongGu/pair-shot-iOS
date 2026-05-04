import SwiftUI

struct AlbumDetailDefaultToolbar: ToolbarContent {
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
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
                Text(allSelected
                    ? String(localized: "home_button_deselect_all")
                    : String(localized: "home_button_select_all")
                )
            }
        }
    }
}

struct AlbumDetailRenameAlert: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel
    let album: AlbumEntity

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
            .alert(
                String(localized: "album_dialog_delete_title"),
                isPresented: $viewModel.showAlbumDeleteAlert
            ) {
                Button(String(localized: "common_button_delete"), role: .destructive) {
                    Task { await viewModel.confirmAlbumDeletion() }
                }
                Button(String(localized: "common_button_cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "album_dialog_delete_message"))
            }
    }
}
