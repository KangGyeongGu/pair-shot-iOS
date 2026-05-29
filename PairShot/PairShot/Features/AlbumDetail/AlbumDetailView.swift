import SwiftUI

struct AlbumDetailView: View {
    let albumId: UUID
    let onPushExportSettings: (([UUID]) -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AlbumDetailViewModel?

    var body: some View {
        AlbumByIdQueryHost(id: albumId) { album in
            PhotoPairQueryHost { allDomainPairs in
                rootContent(album: album, allDomainPairs: allDomainPairs)
            }
        }
    }

    private var pairPickerSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.navigateToPairPicker ?? false },
            set: { newValue in
                if !newValue { viewModel?.navigateToPairPicker = false }
            },
        )
    }

    private var missingAlbumView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(.secondary)
            Text(String(localized: "album_error_not_found"))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    init(
        albumId: UUID,
        onPushExportSettings: (([UUID]) -> Void)? = nil,
    ) {
        self.albumId = albumId
        self.onPushExportSettings = onPushExportSettings
    }

    @ViewBuilder
    private func rootContent(album: Album?, allDomainPairs: [PhotoPair]) -> some View {
        let albumPairs = album.map { current in
            allDomainPairs.filter { current.pairIds.contains($0.id) }
        } ?? []

        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if let viewModel, let album {
                content(for: viewModel, album: album, albumPairs: albumPairs)
            } else if album == nil {
                missingAlbumView
            } else {
                ProgressView()
            }
        }
        .navigationTitle(album?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel?.isSelectionMode == true)
        .toolbar { toolbar(album: album, albumPairs: albumPairs) }
        .task { ensureViewModel() }
        .onChange(of: viewModel?.albumDeleted ?? false) { _, deleted in
            if deleted { dismiss() }
        }
        .sheet(isPresented: pairPickerSheetBinding) {
            NavigationStack {
                PairPickerView(albumId: albumId)
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbar(album: Album?, albumPairs: [PhotoPair]) -> some ToolbarContent {
        if let viewModel, let album {
            let sorted = viewModel.sortedPairs(from: albumPairs)
            if viewModel.isSelectionMode {
                AlbumDetailSelectionToolbar(
                    selectionCount: viewModel.selectedPairIds.count,
                    allSelected: viewModel.areAllPairsSelected(from: sorted),
                    onCancel: viewModel.cancelSelection,
                    onToggleSelectAll: { viewModel.selectAllPairs(from: sorted) },
                )
            } else {
                AlbumDetailDefaultToolbar(
                    onSelect: viewModel.enterSelectionMode,
                    onRename: { viewModel.beginRename(currentName: album.name) },
                    onDelete: { viewModel.requestAlbumDeletion(album: album) },
                )
            }
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeAlbumDetailViewModel(albumId: albumId)
        }
    }

    @ViewBuilder
    private func content(
        for viewModel: AlbumDetailViewModel,
        album: Album,
        albumPairs: [PhotoPair],
    ) -> some View {
        let sortedPairs = viewModel.sortedPairs(from: albumPairs)

        VStack(spacing: 0) {
            BannerAdSlot()

            grid(viewModel: viewModel, pairs: sortedPairs)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AlbumDetailBottomBarHost(
                viewModel: viewModel,
                sortedPairs: sortedPairs,
                onPushExportSettings: onPushExportSettings,
            )
        }
        .modifier(AlbumDetailCameraCovers(viewModel: viewModel))
        .modifier(AlbumDeletePairsDialog(viewModel: viewModel))
        .modifier(AlbumDetailRenameAlert(viewModel: viewModel, album: album))
        .modifier(AlbumDetailDeleteAlbumAlert(viewModel: viewModel))
        .modifier(AlbumDetailShareSheet(viewModel: viewModel))
        .modifier(AlbumDetailPaywallSheet(viewModel: viewModel))
        .modifier(
            AlbumDetailSelectionPruner(
                viewModel: viewModel,
                pairIds: albumPairs.map(\.id),
            ),
        )
    }

    @ViewBuilder
    private func grid(viewModel: AlbumDetailViewModel, pairs: [PhotoPair]) -> some View {
        if pairs.isEmpty {
            AlbumDetailEmptyState()
        } else {
            PairGrid(
                pairs: pairs,
                onRefresh: { await viewModel.reload() },
                cell: { pair in
                    HomePairCardView(
                        pair: pair,
                        isSelectionMode: viewModel.isSelectionMode,
                        isSelected: viewModel.selectedPairIds.contains(pair.id),
                    )
                    .contentShape(.rect)
                    .onTapGesture { viewModel.tapPair(pair, allPairs: pairs) }
                    .onLongPressGesture(minimumDuration: 0.4) { viewModel.longPressPair(pair) }
                    .modifier(PairCardContextMenu(
                        pair: pair,
                        isSelectionMode: viewModel.isSelectionMode,
                        actions: viewModel.pairCardActions,
                    ))
                },
            )
        }
    }
}

struct AlbumDetailCameraCovers: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $viewModel.showBeforeCamera) {
                NavigationStack {
                    BeforeCameraView(
                        albumId: viewModel.albumId,
                        refillPairId: viewModel.beforeCameraTargetPairId,
                    )
                }
            }
            .fullScreenCover(isPresented: $viewModel.showAfterCamera) {
                NavigationStack {
                    AfterCameraView(
                        albumId: viewModel.albumId,
                        initialPairId: viewModel.afterCameraTargetPairId,
                        sortOrder: viewModel.sortOrder,
                    )
                }
            }
            .sheet(item: $viewModel.pendingPreviewPair) { request in
                PairPreviewView(pair: request.pair, actions: viewModel.pairCardActions)
                    .presentationDetents([.fraction(0.7)])
                    .presentationDragIndicator(.visible)
            }
    }
}

struct AlbumDetailShareSheet: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $viewModel.pendingShareItems) { items in
                ShareSheet(activityItems: items.values) {
                    viewModel.clearShareItems()
                }
            }
            .background(
                Color.clear
                    .sheet(
                        item: Binding(
                            get: { viewModel.pendingZipExport },
                            set: { _ in },
                        ),
                    ) { item in
                        DocumentExporter(url: item.url) { saved in
                            viewModel.handleZipExportCompleted(saved)
                        }
                    },
            )
    }
}

struct AlbumDetailPaywallSheet: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    func body(content: Content) -> some View {
        content.paywallSheet(isPresented: $viewModel.showPaywall)
    }
}

private struct AlbumDetailSelectionPruner: ViewModifier {
    let viewModel: AlbumDetailViewModel
    let pairIds: [UUID]

    func body(content: Content) -> some View {
        content.onChange(of: pairIds) { _, newIds in
            viewModel.pruneStalePairSelections(currentIds: Set(newIds))
        }
    }
}
