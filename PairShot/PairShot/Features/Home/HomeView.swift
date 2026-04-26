import SwiftData
import SwiftUI

struct HomeView: View {
    let onOpenAlbum: ((UUID) -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Query(sort: \PhotoPair.createdAt, order: .reverse) private var allPairs: [PhotoPair]
    @Query(sort: \Album.updatedAt, order: .reverse) private var allAlbums: [Album]
    @State private var viewModel: HomeViewModel?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    init(onOpenAlbum: ((UUID) -> Void)? = nil) {
        self.onOpenAlbum = onOpenAlbum
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
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeHomeViewModel()
        }
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
                sortedAlbums: sortedAlbums
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
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(pairs) { pair in
                    HomePairCardView(
                        pair: pair,
                        storage: viewModel.storage,
                        isSelectionMode: viewModel.isSelectionMode,
                        isSelected: viewModel.selectedPairIds.contains(pair.id)
                    )
                    .contentShape(.rect)
                    .onTapGesture { viewModel.tapPair(pair, allPairs: pairs) }
                    .onLongPressGesture(minimumDuration: 0.4) { viewModel.longPressPair(pair) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !viewModel.isSelectionMode {
                            Button(role: .destructive) {
                                viewModel.requestSinglePairDeletion(pair)
                            } label: {
                                Label(String(localized: "삭제"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .refreshable { await viewModel.reload() }
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
                .onLongPressGesture(minimumDuration: 0.4) { viewModel.longPressAlbum(album) }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !viewModel.isSelectionMode {
                        Button(role: .destructive) {
                            viewModel.requestSingleAlbumDeletion(album)
                        } label: {
                            Label(String(localized: "삭제"), systemImage: "trash")
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
