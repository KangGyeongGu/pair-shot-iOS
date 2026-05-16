import SwiftUI

struct HomeBottomBarHost: View {
    let viewModel: HomeViewModel
    let sortedPairs: [PhotoPair]
    let sortedAlbums: [Album]
    let onPushExportSettings: (([UUID]) -> Void)?

    @Environment(ExportCompletionCoordinator.self) private var exportCompletionCoordinator

    var body: some View {
        contents
            .padding(.horizontal, 20)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isSelectionMode)
            .animation(.easeInOut(duration: 0.2), value: viewModel.contentMode)
    }

    @ViewBuilder
    private var contents: some View {
        if viewModel.isSelectionMode {
            switch viewModel.contentMode {
                case .pairs:
                    HomePairSelectionBottomBar(
                        selectionCount: viewModel.selectedPairIds.count,
                        onShare: { Task { await viewModel.shareSelectedPairs(from: sortedPairs) } },
                        onSaveToDevice: { Task { await viewModel.saveSelectedPairsToDevice(from: sortedPairs) } },
                        onDelete: { viewModel.requestPairDeletion(from: sortedPairs) },
                        onExportSettings: pushExport,
                    )

                case .albums:
                    HomePairSelectionBottomBar(
                        selectionCount: viewModel.selectedAlbumIds.count,
                        onShare: {
                            Task {
                                await viewModel.shareSelectedAlbumPairs(
                                    from: sortedAlbums,
                                    allPairs: sortedPairs,
                                )
                            }
                        },
                        onSaveToDevice: {
                            Task {
                                await viewModel.saveSelectedAlbumPairsToDevice(
                                    from: sortedAlbums,
                                    allPairs: sortedPairs,
                                )
                            }
                        },
                        onDelete: { viewModel.requestAlbumDeletion(from: sortedAlbums) },
                        onExportSettings: pushAlbumExport,
                    )
            }
        } else {
            switch viewModel.contentMode {
                case .pairs:
                    HomePrimaryActionBar(
                        title: sortedPairs.isEmpty
                            ? String(localized: "common_button_start_capture")
                            : String(localized: "camera_desc_capture"),
                        systemImage: "camera.fill",
                    ) { Task { await viewModel.startCapture() } }

                case .albums:
                    HomePrimaryActionBar(
                        title: String(localized: "home_button_create_album"),
                        systemImage: "plus.rectangle.on.rectangle",
                    ) { viewModel.openCreateAlbum() }
            }
        }
    }

    private func pushExport() {
        let chosen =
            sortedPairs
                .filter { viewModel.selectedPairIds.contains($0.id) }
                .map(\.id)
        guard !chosen.isEmpty else { return }
        exportCompletionCoordinator.register { [weak viewModel] in
            viewModel?.cancelSelection()
        }
        onPushExportSettings?(chosen)
    }

    private func pushAlbumExport() {
        let pairIds =
            sortedAlbums
                .filter { viewModel.selectedAlbumIds.contains($0.id) }
                .flatMap(\.pairIds)
        let unique = Array(Set(pairIds))
        guard !unique.isEmpty else { return }
        exportCompletionCoordinator.register { [weak viewModel] in
            viewModel?.cancelSelection()
        }
        onPushExportSettings?(unique)
    }
}
