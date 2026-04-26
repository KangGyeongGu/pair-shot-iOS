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
                    Label(String(localized: "이름 변경"), systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(String(localized: "삭제"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(String(localized: "더 보기"))
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
            .accessibilityLabel(String(localized: "선택 해제"))
        }
        ToolbarItem(placement: .principal) {
            Text(String(format: String(localized: "%lld개 선택"), selectionCount))
                .font(.headline)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onToggleSelectAll) {
                Text(allSelected
                    ? String(localized: "전체해제")
                    : String(localized: "전체선택")
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
                String(localized: "앨범 이름 수정"),
                isPresented: $viewModel.showRenameAlert
            ) {
                TextField(String(localized: "앨범 이름 입력"), text: $viewModel.renameDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                Button(String(localized: "저장")) {
                    Task { await viewModel.confirmRename(album: album) }
                }
                .disabled(viewModel.renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(String(localized: "취소"), role: .cancel) {}
            }
    }
}

struct AlbumDetailDeleteAlbumAlert: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "앨범 삭제"),
                isPresented: $viewModel.showAlbumDeleteAlert
            ) {
                Button(String(localized: "삭제"), role: .destructive) {
                    Task { await viewModel.confirmAlbumDeletion() }
                }
                Button(String(localized: "취소"), role: .cancel) {}
            } message: {
                Text(String(localized: "앨범을 삭제하시겠습니까? 페어는 유지됩니다."))
            }
    }
}
