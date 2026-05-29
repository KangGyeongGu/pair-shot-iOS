import StoreKit
import SwiftUI

struct HomeView: View {
    let onOpenAlbum: ((UUID) -> Void)?
    let onPushExportSettings: (([UUID]) -> Void)?
    let onPushSettings: (() -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Environment(Membership.self) private var membership
    @Environment(\.requestReview) private var requestReview
    @State private var viewModel: HomeViewModel?
    @State private var didCheckReviewThisSession = false

    var body: some View {
        PhotoPairQueryHost { domainPairs in
            AlbumQueryHost { domainAlbums in
                rootContent(domainPairs: domainPairs, domainAlbums: domainAlbums)
            }
        }
    }

    init(
        onOpenAlbum: ((UUID) -> Void)? = nil,
        onPushExportSettings: (([UUID]) -> Void)? = nil,
        onPushSettings: (() -> Void)? = nil,
    ) {
        self.onOpenAlbum = onOpenAlbum
        self.onPushExportSettings = onPushExportSettings
        self.onPushSettings = onPushSettings
    }

    private func rootContent(domainPairs: [PhotoPair], domainAlbums: [Album]) -> some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if let viewModel {
                content(for: viewModel, domainPairs: domainPairs, domainAlbums: domainAlbums)
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbar(domainPairs: domainPairs, domainAlbums: domainAlbums) }
        .task { ensureViewModel() }
        .onAppear {
            consumePendingSettingsRedirectIfNeeded()
            requestReviewIfEligible()
        }
        .onChange(of: env.settingsRedirectCoordinator.pendingPulse) { _, _ in
            consumePendingSettingsRedirectIfNeeded()
        }
        .modifier(HomeTutorialResumeAfterCamera(viewModel: viewModel, domainPairs: domainPairs))
    }

    @ToolbarContentBuilder
    private func toolbar(domainPairs: [PhotoPair], domainAlbums: [Album]) -> some ToolbarContent {
        if let viewModel, viewModel.isSelectionMode {
            HomeSelectionToolbar(
                viewModel: viewModel,
                sortedPairs: viewModel.sortedPairs(from: domainPairs),
                sortedAlbums: viewModel.sortedAlbums(from: domainAlbums),
            )
        } else {
            HomeDefaultToolbar(
                viewModel: viewModel,
                onPushSettings: onPushSettings,
                isPro: membership.proIsActive,
                tutorialActive: env.tutorialCoordinator.isActive,
                tutorialPairIds: env.tutorialCoordinator.isActive
                    ? domainPairs.filter(\.isTutorial).map(\.id)
                    : [],
                onTutorialAdvanceAfterSelectionMode: {
                    if env.tutorialCoordinator.isAtStep(.enterSelectionMode) {
                        env.tutorialCoordinator.advance()
                    }
                },
                onTutorialAdvanceAfterSettings: {
                    if env.tutorialCoordinator.isAtStep(.goSettings) {
                        env.tutorialCoordinator.advance()
                    }
                },
            )
        }
    }

    @ViewBuilder
    private func content(
        for viewModel: HomeViewModel,
        domainPairs: [PhotoPair],
        domainAlbums: [Album],
    ) -> some View {
        @Bindable var bindable = viewModel
        let sortedPairs = viewModel.sortedPairs(from: domainPairs)
        let sortedAlbums = viewModel.sortedAlbums(from: domainAlbums)

        VStack(spacing: 0) {
            BannerAdSlot()

            HomeFilterRow(
                contentMode: $bindable.contentMode,
                sortOrder: $bindable.sortOrder,
                onModeChange: viewModel.switchContentMode(to:),
                onSortOrderChange: viewModel.setSortOrder(_:),
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .disabled(viewModel.isSelectionMode)

            grids(viewModel: viewModel, sortedPairs: sortedPairs, sortedAlbums: sortedAlbums)
        }
        .overlay(alignment: .bottom) {
            HomeBottomBarHost(
                viewModel: viewModel,
                sortedPairs: sortedPairs,
                sortedAlbums: sortedAlbums,
                onPushExportSettings: onPushExportSettings,
            )
        }
        .modifier(HomeViewSheetModifiers(viewModel: viewModel))
        .modifier(
            HomeSelectionPruner(
                viewModel: viewModel,
                pairIds: domainPairs.map(\.id),
                albumIds: domainAlbums.map(\.id),
            ),
        )
    }

    @ViewBuilder
    private func grids(
        viewModel: HomeViewModel,
        sortedPairs: [PhotoPair],
        sortedAlbums: [Album],
    ) -> some View {
        switch viewModel.contentMode {
            case .pairs:
                if sortedPairs.isEmpty {
                    HomeEmptyState(variant: .pairs)
                } else {
                    HomePairsGrid(viewModel: viewModel, pairs: sortedPairs)
                }

            case .albums:
                if sortedAlbums.isEmpty {
                    HomeEmptyState(variant: .albums)
                } else {
                    HomeAlbumsGrid(viewModel: viewModel, albums: sortedAlbums, onOpenAlbum: onOpenAlbum)
                }
        }
    }
}

extension HomeView {
    func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeHomeViewModel()
        }
    }

    func consumePendingSettingsRedirectIfNeeded() {
        guard env.settingsRedirectCoordinator.pendingPulse != nil else { return }
        guard viewModel != nil else {
            DispatchQueue.main.async { consumePendingSettingsRedirectIfNeeded() }
            return
        }
        onPushSettings?()
    }

    private func requestReviewIfEligible() {
        guard !didCheckReviewThisSession else { return }
        didCheckReviewThisSession = true
        let eligible = ReviewRequestGate.shouldRequest(
            launchCount: env.appSettings.launchCount,
            didRequest: env.appSettings.didRequestReview,
            tutorialActive: env.tutorialCoordinator.isActive,
        )
        guard eligible else { return }
        requestReview()
        env.appSettings.didRequestReview = true
    }
}

#Preview {
    PreviewEnvironment(suiteName: "preview-home") {
        NavigationStack {
            HomeView()
        }
    }
}
