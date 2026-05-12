import SwiftData
import SwiftUI

struct HomeView: View {
    let onOpenAlbum: ((UUID) -> Void)?
    let onPushExportSettings: (([UUID]) -> Void)?
    let onPushSettings: (() -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Environment(AdFreeStore.self) private var adFreeStore
    @Query(sort: \PhotoPairEntity.createdAt, order: .reverse) private var allPairs: [PhotoPairEntity]
    @Query(sort: \AlbumEntity.updatedAt, order: .reverse) private var allAlbums: [AlbumEntity]
    @State private var viewModel: HomeViewModel?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbar }
        .task { ensureViewModel() }
        .onAppear { consumePendingSettingsRedirectIfNeeded() }
        .onChange(of: env.settingsRedirectCoordinator.pendingPulse) { _, _ in
            consumePendingSettingsRedirectIfNeeded()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let viewModel, viewModel.isSelectionMode {
            HomeSelectionToolbar(
                viewModel: viewModel,
                sortedPairs: viewModel.sortedPairs(from: allPairs.map { $0.toDomain() }),
                sortedAlbums: viewModel.sortedAlbums(from: allAlbums.map { Self.toDomain($0) })
            )
        } else {
            HomeDefaultToolbar(viewModel: viewModel, onPushSettings: onPushSettings)
        }
    }

    init(
        onOpenAlbum: ((UUID) -> Void)? = nil,
        onPushExportSettings: (([UUID]) -> Void)? = nil,
        onPushSettings: (() -> Void)? = nil
    ) {
        self.onOpenAlbum = onOpenAlbum
        self.onPushExportSettings = onPushExportSettings
        self.onPushSettings = onPushSettings
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeHomeViewModel()
        }
    }

    private func consumePendingSettingsRedirectIfNeeded() {
        guard env.settingsRedirectCoordinator.pendingPulse != nil else { return }
        guard viewModel != nil else {
            DispatchQueue.main.async { consumePendingSettingsRedirectIfNeeded() }
            return
        }
        onPushSettings?()
    }

    @ViewBuilder
    private func content(for viewModel: HomeViewModel) -> some View {
        @Bindable var bindable = viewModel
        let domainPairs = allPairs.map { $0.toDomain() }
        let domainAlbums = allAlbums.map { Self.toDomain($0) }
        let sortedPairs = viewModel.sortedPairs(from: domainPairs)
        let sortedAlbums = viewModel.sortedAlbums(from: domainAlbums)

        VStack(spacing: 0) {
            BannerAdSlot()

            HomeFilterRow(
                contentMode: $bindable.contentMode,
                sortOrder: $bindable.sortOrder,
                onModeChange: viewModel.switchContentMode(to:),
                onSortOrderChange: viewModel.setSortOrder(_:)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .disabled(viewModel.isSelectionMode)

            grids(viewModel: viewModel, sortedPairs: sortedPairs, sortedAlbums: sortedAlbums)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HomeBottomBarHost(
                viewModel: viewModel,
                sortedPairs: sortedPairs,
                sortedAlbums: sortedAlbums,
                onPushExportSettings: onPushExportSettings
            )
        }
        .modifier(HomeViewSheetModifiers(viewModel: viewModel))
    }

    @ViewBuilder
    private func grids(
        viewModel: HomeViewModel,
        sortedPairs: [PhotoPair],
        sortedAlbums: [Album]
    ) -> some View {
        switch viewModel.contentMode {
            case .pairs:
                if sortedPairs.isEmpty {
                    HomeEmptyState(variant: .pairs)
                } else {
                    pairsGrid(viewModel: viewModel, pairs: sortedPairs)
                }

            case .albums:
                if sortedAlbums.isEmpty {
                    HomeEmptyState(variant: .albums)
                } else {
                    albumsGrid(viewModel: viewModel, albums: sortedAlbums)
                }
        }
    }

    private func pairsGrid(viewModel: HomeViewModel, pairs: [PhotoPair]) -> some View {
        let groups = viewModel.groupedPairs(from: pairs)
        var slotIndex = 0
        let groupChunks: [(date: Date, pairs: [PhotoPair], chunks: [PairListWithAdsBuilder.PairChunk])] =
            groups
                .map { group in
                    let result = PairListWithAdsBuilder.buildChunks(
                        pairs: group.pairs,
                        adFree: adFreeStore.isAdFree,
                        startingAdSlotIndex: slotIndex
                    )
                    slotIndex = result.nextSlotIndex
                    return (group.date, group.pairs, result.chunks)
                }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(groupChunks, id: \.date) { group in
                    pairDateSection(
                        viewModel: viewModel,
                        date: group.date,
                        pairs: group.pairs,
                        chunks: group.chunks
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable { await viewModel.reload() }
    }

    private func pairDateSection(
        viewModel: HomeViewModel,
        date: Date,
        pairs: [PhotoPair],
        chunks: [PairListWithAdsBuilder.PairChunk]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.formatDateHeader(date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appOnSurfaceVariant)
                .padding(.horizontal, 12)

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
    }

    private func pairCell(
        viewModel: HomeViewModel,
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

    private func albumsGrid(viewModel: HomeViewModel, albums: [Album]) -> some View {
        List {
            ForEach(viewModel.groupedAlbums(from: albums), id: \.date) { group in
                Section {
                    ForEach(group.albums) { album in
                        albumCell(viewModel: viewModel, album: album)
                    }
                } header: {
                    Text(Self.formatDateHeader(group.date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appOnSurfaceVariant)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.reload() }
    }

    private func albumCell(viewModel: HomeViewModel, album: Album) -> some View {
        HomeAlbumCardView(
            album: album,
            isSelectionMode: viewModel.isSelectionMode,
            isSelected: viewModel.selectedAlbumIds.contains(album.id)
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

    static func formatDateHeader(_ date: Date, now _: Date = .now, calendar: Calendar = .current) -> String {
        HomeDateFormatter.base(for: date, calendar: calendar)
    }

    static func toDomain(_ entity: AlbumEntity) -> Album {
        Album(
            name: entity.name,
            id: entity.id,
            latitude: entity.latitude,
            longitude: entity.longitude,
            locationLabel: entity.locationLabel,
            createdAt: entity.createdAt,
            pairIds: entity.pairs.map(\.id)
        )
    }
}

enum HomeDateFormatter {
    static func base(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("yMd")
        return formatter.string(from: date)
    }
}

#Preview {
    PreviewEnvironment(suiteName: "preview-home") {
        NavigationStack {
            HomeView()
        }
    }
}
