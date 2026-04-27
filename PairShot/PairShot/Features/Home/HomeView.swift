import SwiftData
import SwiftUI

struct HomeView: View {
    let onOpenAlbum: ((UUID) -> Void)?
    let onPushExportSettings: (([UUID]) -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Environment(AdFreeStore.self) private var adFreeStore
    @Query(sort: \PhotoPair.createdAt, order: .reverse) private var allPairs: [PhotoPair]
    @Query(sort: \Album.updatedAt, order: .reverse) private var allAlbums: [Album]
    @State private var viewModel: HomeViewModel?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    init(
        onOpenAlbum: ((UUID) -> Void)? = nil,
        onPushExportSettings: (([UUID]) -> Void)? = nil
    ) {
        self.onOpenAlbum = onOpenAlbum
        self.onPushExportSettings = onPushExportSettings
    }

    var body: some View {
        ZStack {
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

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeHomeViewModel()
        }
    }

    private func consumePendingSettingsRedirectIfNeeded() {
        guard env.settingsRedirectCoordinator.pendingPulse != nil else { return }
        guard let viewModel else {
            DispatchQueue.main.async { consumePendingSettingsRedirectIfNeeded() }
            return
        }
        viewModel.showSettings = true
    }

    @ViewBuilder
    private func content(for viewModel: HomeViewModel) -> some View {
        @Bindable var bindable = viewModel
        let sortedPairs = viewModel.sortedPairs(from: allPairs)
        let sortedAlbums = viewModel.sortedAlbums(from: allAlbums)

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
        .modifier(HomeViewSheetModifiers(
            viewModel: viewModel,
            sortedPairs: sortedPairs,
            sortedAlbums: sortedAlbums
        ))
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
                    albumsList(viewModel: viewModel, albums: sortedAlbums)
                }
        }
    }

    private func pairsGrid(viewModel: HomeViewModel, pairs: [PhotoPair]) -> some View {
        let groups = viewModel.groupedPairs(from: pairs)
        let isAdFree = adFreeStore.isAdFree
        var slotIndex = 0
        let groupChunks: [(date: Date, pairs: [PhotoPair], chunks: [PairListWithAdsBuilder.PairChunk])] = groups.map { group in
            let result = PairListWithAdsBuilder.buildChunks(
                pairs: group.pairs,
                adFree: isAdFree,
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
            storage: viewModel.storage,
            isSelectionMode: viewModel.isSelectionMode,
            isSelected: viewModel.selectedPairIds.contains(pair.id)
        )
        .contentShape(.rect)
        .onTapGesture { viewModel.tapPair(pair, allPairs: allPairs) }
        .contextMenu {
            if !viewModel.isSelectionMode {
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

    static func formatDateHeader(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let base = HomeDateFormatter.base(for: date, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: date)
        if target == today {
            return String(format: String(localized: "home_date_suffix_today"), base)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), target == yesterday {
            return String(format: String(localized: "home_date_suffix_yesterday"), base)
        }
        return base
    }

    private func albumsList(viewModel: HomeViewModel, albums: [Album]) -> some View {
        List {
            ForEach(albums) { album in
                HomeAlbumCardView(
                    album: album,
                    isSelectionMode: viewModel.isSelectionMode,
                    isSelected: viewModel.selectedAlbumIds.contains(album.id)
                )
                .listRowInsets(EdgeInsets())
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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.reload() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let viewModel, viewModel.isSelectionMode {
            HomeSelectionToolbar(
                viewModel: viewModel,
                sortedPairs: viewModel.sortedPairs(from: allPairs),
                sortedAlbums: viewModel.sortedAlbums(from: allAlbums)
            )
        } else {
            HomeDefaultToolbar(viewModel: viewModel)
        }
    }
}

enum HomeDateFormatter {
    static func base(for date: Date, calendar: Calendar = .current, now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = calendar
        let dateYear = calendar.component(.year, from: date)
        let nowYear = calendar.component(.year, from: now)
        formatter.setLocalizedDateFormatFromTemplate(dateYear == nowYear ? "Md" : "yMd")
        return formatter.string(from: date)
    }
}

private struct RootViewPreviewWrapper: View {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Schema(versionedSchema: SchemaV2.self),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        let appSettings = AppSettings(defaults: UserDefaults(suiteName: "preview-home") ?? .standard)
        let env = AppEnvironment(modelContainer: container, appSettings: appSettings)
        return NavigationStack {
            HomeView()
        }
        .modelContainer(container)
        .environment(env)
        .environment(env.adFreeStore)
        .environment(\.fullscreenAdCoordinator, env.fullscreenAdCoordinator)
        .environment(env.interstitialAdManager)
        .environment(env.nativeAdLoader)
        .environment(env.appSettings)
    }
}

#Preview {
    RootViewPreviewWrapper()
}
