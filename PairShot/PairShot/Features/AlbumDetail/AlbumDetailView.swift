import SwiftUI

struct AlbumDetailView: View {
    let albumId: UUID
    let onPushExportSettings: (([UUID]) -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Environment(Entitlement.self) private var entitlement
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AlbumDetailViewModel?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

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
            }
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
        onPushExportSettings: (([UUID]) -> Void)? = nil
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
                    onToggleSelectAll: { viewModel.selectAllPairs(from: sorted) }
                )
            } else {
                AlbumDetailDefaultToolbar(
                    onSelect: viewModel.enterSelectionMode,
                    onRename: { viewModel.beginRename(currentName: album.name) },
                    onDelete: { viewModel.requestAlbumDeletion(album: album) }
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
        albumPairs: [PhotoPair]
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
                onPushExportSettings: onPushExportSettings
            )
        }
        .modifier(AlbumDetailCameraCovers(viewModel: viewModel))
        .modifier(AlbumDeletePairsDialog(viewModel: viewModel))
        .modifier(AlbumDetailRenameAlert(viewModel: viewModel, album: album))
        .modifier(AlbumDetailDeleteAlbumAlert(viewModel: viewModel))
        .modifier(AlbumDetailShareSheet(viewModel: viewModel))
        .modifier(AlbumDetailPaywallSheet(viewModel: viewModel))
    }

    @ViewBuilder
    private func grid(viewModel: AlbumDetailViewModel, pairs: [PhotoPair]) -> some View {
        if pairs.isEmpty {
            AlbumDetailEmptyState()
        } else {
            let chunks = PairListWithAdsBuilder.buildChunks(
                pairs: pairs,
                adFree: entitlement.isAdSuppressed
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
            isSelectionMode: viewModel.isSelectionMode,
            isSelected: viewModel.selectedPairIds.contains(pair.id)
        )
        .contentShape(.rect)
        .onTapGesture { viewModel.tapPair(pair, allPairs: allPairs) }
        .onLongPressGesture(minimumDuration: 0.4) { viewModel.longPressPair(pair) }
        .contextMenu {
            if !viewModel.isSelectionMode {
                if pair.afterPhotoLocalIdentifier != nil {
                    Button {
                        viewModel.requestRecaptureAfter(pair)
                    } label: {
                        Label(
                            String(localized: "pair_preview_menu_recapture"),
                            systemImage: "camera.rotate"
                        )
                    }
                }
                Button {
                    Task { await viewModel.sharePair(pair) }
                } label: {
                    Label(
                        String(localized: "common_button_share"),
                        systemImage: "square.and.arrow.up"
                    )
                }
                Button {
                    Task { await viewModel.exportPair(pair) }
                } label: {
                    Label(
                        String(localized: "common_button_export"),
                        systemImage: "square.and.arrow.down"
                    )
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
            .fullScreenCover(item: $viewModel.pendingRecaptureAfter) { request in
                NavigationStack {
                    AfterCameraView(recaptureTargetPair: request.pair)
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
                    .sheet(
                        item: Binding(
                            get: { viewModel.pendingZipExport },
                            set: { newValue in
                                if newValue == nil, viewModel.pendingZipExport != nil {
                                    viewModel.handleZipExportCompleted(false)
                                }
                            }
                        )
                    ) { item in
                        DocumentExporter(url: item.url) { saved in
                            viewModel.handleZipExportCompleted(saved)
                        }
                    }
            )
    }
}

struct AlbumDetailPaywallSheet: ViewModifier {
    @Bindable var viewModel: AlbumDetailViewModel

    func body(content: Content) -> some View {
        content.paywallSheet(isPresented: $viewModel.showPaywall)
    }
}
