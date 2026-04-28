import SwiftData
import SwiftUI

struct AlbumDetailView: View {
    let albumId: UUID
    let onPushExportSettings: (([UUID]) -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Environment(AdFreeStore.self) private var adFreeStore
    @Environment(\.dismiss) private var dismiss
    @Query private var albums: [Album]

    @State private var viewModel: AlbumDetailViewModel?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    init(
        albumId: UUID,
        onPushExportSettings: (([UUID]) -> Void)? = nil
    ) {
        self.albumId = albumId
        self.onPushExportSettings = onPushExportSettings
        let predicate = #Predicate<Album> { $0.id == albumId }
        _albums = Query(filter: predicate)
    }

    var body: some View {
        ZStack {
            if let viewModel, let album = albums.first {
                content(for: viewModel, album: album)
            } else if albums.isEmpty {
                missingAlbumView
            } else {
                ProgressView()
            }
        }
        .navigationTitle(albums.first?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task { ensureViewModel() }
        .onChange(of: viewModel?.albumDeleted ?? false) { _, deleted in
            if deleted { dismiss() }
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeAlbumDetailViewModel(albumId: albumId)
        }
    }

    @ViewBuilder
    private func content(for viewModel: AlbumDetailViewModel, album: Album) -> some View {
        let sortedPairs = viewModel.sortedPairs(from: album)

        VStack(spacing: 0) {
            BannerAdSlot()

            grid(viewModel: viewModel, pairs: sortedPairs)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AlbumDetailBottomBarHost(
                viewModel: viewModel,
                sortedPairs: sortedPairs,
                onPushExportSettings: onPushExportSettings
            )
        }
        .modifier(AlbumDetailCameraCovers(viewModel: viewModel))
        .modifier(AlbumDeletePairsDialog(viewModel: viewModel))
        .modifier(AlbumDetailRenameAlert(viewModel: viewModel, album: album))
        .modifier(AlbumDetailDeleteAlbumAlert(viewModel: viewModel))
        .modifier(AlbumDetailPairPickerNavigation(viewModel: viewModel))
        .modifier(AlbumDetailShareSheet(viewModel: viewModel))
    }

    @ViewBuilder
    private func grid(viewModel: AlbumDetailViewModel, pairs: [PhotoPair]) -> some View {
        if pairs.isEmpty {
            AlbumDetailEmptyState()
        } else {
            let chunks = PairListWithAdsBuilder.buildChunks(
                pairs: pairs,
                adFree: adFreeStore.isAdFree
            ).chunks
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chunks) { chunk in
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(chunk.pairs) { pair in
                                pairCell(viewModel: viewModel, pair: pair, allPairs: pairs)
                            }
                        }
                        .padding(.horizontal, 12)

                        if let adSlotIndex = chunk.adSlotIndex {
                            NativeAdCard(slotIndex: adSlotIndex)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .refreshable { await viewModel.reload() }
        }
    }

    private func pairCell(
        viewModel: AlbumDetailViewModel,
        pair: PhotoPair,
        allPairs: [PhotoPair]
    ) -> some View {
        HomePairCardView(
            pair: pair,
            storage: viewModel.storage,
            isSelectionMode: viewModel.isSelectionMode,
            isSelected: viewModel.selectedPairIds.contains(pair.id)
        )
        .contentShape(.rect)
        .onTapGesture { viewModel.tapPair(pair, allPairs: allPairs) }
        .onLongPressGesture(minimumDuration: 0.4) { viewModel.longPressPair(pair) }
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

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let viewModel, let album = albums.first {
            if viewModel.isSelectionMode {
                AlbumDetailSelectionToolbar(
                    selectionCount: viewModel.selectedPairIds.count,
                    allSelected: viewModel.areAllPairsSelected(from: viewModel.sortedPairs(from: album)),
                    onCancel: viewModel.cancelSelection,
                    onToggleSelectAll: { viewModel.selectAllPairs(from: viewModel.sortedPairs(from: album)) }
                )
            } else {
                AlbumDetailDefaultToolbar(
                    onRename: { viewModel.beginRename(currentName: album.name) },
                    onDelete: viewModel.requestAlbumDeletion
                )
            }
        }
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
}

struct AlbumDetailCameraCovers: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $viewModel.showBeforeCamera) {
                NavigationStack { BeforeCameraView(albumId: viewModel.albumId) }
            }
            .fullScreenCover(isPresented: $viewModel.showAfterCamera) {
                NavigationStack {
                    AfterCameraView(
                        albumId: viewModel.albumId,
                        initialPairId: viewModel.afterCameraTargetPairId,
                        sortOrder: viewModel.sortOrder
                    )
                }
            }
            .sheet(item: $viewModel.pendingPreviewPair) { request in
                PairPreviewView(pair: request.pair)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

struct AlbumDetailPairPickerNavigation: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $viewModel.navigateToPairPicker) {
                PairPickerView(albumId: viewModel.albumId)
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
                    .sheet(item: Binding(
                        get: { viewModel.pendingZipExport },
                        set: { newValue in
                            if newValue == nil, viewModel.pendingZipExport != nil {
                                viewModel.handleZipExportCompleted(false)
                            }
                        }
                    )) { item in
                        DocumentExporter(url: item.url) { saved in
                            viewModel.handleZipExportCompleted(saved)
                        }
                    }
            )
    }
}
