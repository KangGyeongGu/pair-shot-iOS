import SwiftUI

struct HomeAlbumsGrid: View {
    let viewModel: HomeViewModel
    let albums: [Album]
    let onOpenAlbum: ((UUID) -> Void)?

    var body: some View {
        List {
            ForEach(viewModel.groupedAlbums(from: albums), id: \.date) { group in
                Section {
                    ForEach(group.albums) { album in
                        albumCell(album: album)
                    }
                } header: {
                    Text(HomeDateFormatter.base(for: group.date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appOnSurfaceVariant)
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.bottom, 40, for: .scrollContent)
        .refreshable { await viewModel.reload() }
    }

    private func albumCell(album: Album) -> some View {
        HomeAlbumCardView(
            album: album,
            isSelectionMode: viewModel.isSelectionMode,
            isSelected: viewModel.selectedAlbumIds.contains(album.id),
        )
        .contentShape(.rect)
        .onTapGesture {
            if viewModel.isSelectionMode {
                viewModel.tapAlbum(album)
            } else {
                onOpenAlbum?(album.id)
            }
        }
        .contextMenu {
            if !viewModel.isSelectionMode {
                Button(role: .destructive) {
                    viewModel.requestSingleAlbumDeletion(album)
                } label: {
                    Label(String(localized: "common_button_delete"), systemImage: "trash")
                }
            }
        }
    }
}
