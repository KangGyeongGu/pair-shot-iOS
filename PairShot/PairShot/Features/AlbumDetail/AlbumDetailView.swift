import SwiftData
import SwiftUI

struct AlbumDetailView: View {
    let albumId: UUID
    let onPushExportSettings: (([UUID]) -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Query private var albums: [AlbumEntity]

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
        let predicate = #Predicate<AlbumEntity> { $0.id == albumId }
        _albums = Query(filter: predicate)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
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
        .navigationBarBackButtonHidden(viewModel?.isSelectionMode == true)
        .toolbar { toolbar }
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

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeAlbumDetailViewModel(albumId: albumId)
        }
    }

    private var pairPickerSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.navigateToPairPicker ?? false },
            set: { newValue in
                if !newValue { viewModel?.navigateToPairPicker = false }
            }
        )
    }

    @ViewBuilder
    private func content(for viewModel: AlbumDetailViewModel, album: AlbumEntity) -> some View {
        let domainPairs = album.pairs.map { $0.toDomain() }
        let sortedPairs = viewModel.sortedPairs(from: domainPairs)
        let domainAlbum = Self.toDomain(album)

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
        .modifier(AlbumDetailRenameAlert(viewModel: viewModel, album: domainAlbum))
        .modifier(AlbumDetailDeleteAlbumAlert(viewModel: viewModel))
        .modifier(AlbumDetailShareSheet(viewModel: viewModel))
    }

    static func toDomain(_ entity: AlbumEntity) -> Album {
        Album(
            id: entity.id,
            name: entity.name,
            latitude: entity.latitude,
            longitude: entity.longitude,
            locationLabel: entity.locationLabel,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            pairIds: entity.pairs.map(\.id)
        )
    }

    @ViewBuilder
    private func grid(viewModel: AlbumDetailViewModel, pairs: [PhotoPair]) -> some View {
        if pairs.isEmpty {
            AlbumDetailEmptyState()
        } else {
            let chunks = PairListWithAdsBuilder.buildChunks(pairs: pairs).chunks
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
            isSelectionMode: viewModel.isSelectionMode,
            isSelected: viewModel.selectedPairIds.contains(pair.id)
        )
        .contentShape(.rect)
        .onTapGesture { viewModel.tapPair(pair, allPairs: allPairs) }
        .onLongPressGesture(minimumDuration: 0.4) { viewModel.longPressPair(pair) }
        .contextMenu {
            if !viewModel.isSelectionMode {
                if pair.hasCombinedExport {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteCombinedExports(for: pair) }
                    } label: {
                        Label(
                            String(localized: "pair_card_action_delete_combined"),
                            systemImage: "square.on.square"
                        )
                    }
                }
                Button(role: .destructive) {
                    viewModel.requestSinglePairDeletion(pair)
                } label: {
                    Label(String(localized: "common_button_delete"), systemImage: "trash")
                }
            }
        }
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
            let domainPairs = album.pairs.map { $0.toDomain() }
            let sorted = viewModel.sortedPairs(from: domainPairs)
            let domainAlbum = Self.toDomain(album)
            if viewModel.isSelectionMode {
                AlbumDetailSelectionToolbar(
                    selectionCount: viewModel.selectedPairIds.count,
                    allSelected: viewModel.areAllPairsSelected(from: sorted),
                    onCancel: viewModel.cancelSelection,
                    onToggleSelectAll: { viewModel.selectAllPairs(from: sorted) }
                )
            } else {
                AlbumDetailDefaultToolbar(
                    onSelect: viewModel.enterSelectionMode,
                    onRename: { viewModel.beginRename(currentName: album.name) },
                    onDelete: { viewModel.requestAlbumDeletion(album: domainAlbum) }
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
                NavigationStack {
                    BeforeCameraView(
                        albumId: viewModel.albumId,
                        refillPairId: viewModel.beforeCameraTargetPairId
                    )
                }
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
