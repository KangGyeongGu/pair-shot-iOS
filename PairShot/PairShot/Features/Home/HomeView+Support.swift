import SwiftUI

struct HomeSelectionToolbar: ToolbarContent {
    let viewModel: HomeViewModel
    let sortedPairs: [PhotoPair]
    let sortedAlbums: [Album]

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.cancelSelection()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(String(localized: "home_desc_deselect"))
        }
        ToolbarItem(placement: .principal) {
            Text(String(format: String(localized: "home_topbar_selection_count_int"), selectionCount))
                .font(.headline)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: toggleSelectAll) {
                Text(
                    allSelected
                        ? String(localized: "home_button_deselect_all")
                        : String(localized: "home_button_select_all"),
                )
            }
        }
    }

    private var selectionCount: Int {
        switch viewModel.contentMode {
            case .pairs: viewModel.selectedPairIds.count
            case .albums: viewModel.selectedAlbumIds.count
        }
    }

    private var allSelected: Bool {
        switch viewModel.contentMode {
            case .pairs: viewModel.areAllPairsSelected(from: sortedPairs)
            case .albums: viewModel.areAllAlbumsSelected(from: sortedAlbums)
        }
    }

    private func toggleSelectAll() {
        switch viewModel.contentMode {
            case .pairs: viewModel.selectAllPairs(from: sortedPairs)
            case .albums: viewModel.selectAllAlbums(from: sortedAlbums)
        }
    }
}

struct HomeDefaultToolbar: ToolbarContent {
    let viewModel: HomeViewModel?
    let onPushSettings: (() -> Void)?
    let isPro: Bool
    let tutorialActive: Bool
    let tutorialPairIds: [UUID]
    let onTutorialAdvanceAfterSelectionMode: () -> Void
    let onTutorialAdvanceAfterSettings: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(String(localized: "PairShot"))
                    .font(isPro ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
                    .foregroundStyle(.primary)
                if isPro {
                    Text(verbatim: "Pro")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule().stroke(Color.accentColor, lineWidth: 1.2),
                        )
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                if tutorialActive {
                    viewModel?.enterSelectionMode(autoSelectingPairIds: tutorialPairIds)
                    onTutorialAdvanceAfterSelectionMode()
                } else {
                    viewModel?.enterSelectionMode()
                }
            } label: {
                Image(systemName: "checkmark.circle")
            }
            .accessibilityLabel(String(localized: "home_desc_selection_mode"))
            .disabled(viewModel == nil)
            .tutorialAnchor(TutorialAnchorID.homeSelectionToggle)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                onPushSettings?()
                onTutorialAdvanceAfterSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(String(localized: "common_label_settings"))
            .disabled(onPushSettings == nil)
            .tutorialAnchor(TutorialAnchorID.homeSettings)
        }
    }
}

struct HomeViewSheetModifiers: ViewModifier {
    @Bindable var viewModel: HomeViewModel

    func body(content: Content) -> some View {
        content
            .modifier(HomeCameraCovers(viewModel: viewModel))
            .modifier(HomeSheets(viewModel: viewModel))
            .modifier(HomeDeleteDialogs(viewModel: viewModel))
            .modifier(HomeAfterDeleteAlert(viewModel: viewModel))
            .paywallSheet(isPresented: $viewModel.showPaywall)
    }
}

struct HomeAfterDeleteAlert: ViewModifier {
    @Bindable var viewModel: HomeViewModel

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "pair_card_alert_delete_after_title"),
            isPresented: Binding(
                get: { viewModel.pendingAfterDelete != nil },
                set: { if !$0 { viewModel.pendingAfterDelete = nil } },
            ),
            presenting: viewModel.pendingAfterDelete,
        ) { request in
            Button(String(localized: "common_button_cancel"), role: .cancel) {
                viewModel.pendingAfterDelete = nil
            }
            Button(String(localized: "common_button_delete"), role: .destructive) {
                Task {
                    await viewModel.confirmAfterDeletion(request.pair)
                    viewModel.pendingAfterDelete = nil
                }
            }
        } message: { _ in
            Text(String(localized: "pair_card_alert_delete_after_message"))
        }
    }
}

struct HomeCameraCovers: ViewModifier {
    @Bindable var viewModel: HomeViewModel
    @Environment(AppEnvironment.self) private var env

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $viewModel.showBeforeCamera) {
                NavigationStack {
                    BeforeCameraView(refillPairId: viewModel.beforeCameraTargetPairId)
                }
                .environment(env)
                .environment(env.tutorialCoordinator)
                .environment(\.tutorialMode, env.tutorialCoordinator.mode)
            }
            .fullScreenCover(isPresented: $viewModel.showAfterCamera) {
                NavigationStack {
                    AfterCameraView(
                        initialPairId: viewModel.afterCameraTargetPairId,
                        sortOrder: viewModel.sortOrder,
                    )
                }
                .environment(env)
                .environment(env.tutorialCoordinator)
                .environment(\.tutorialMode, env.tutorialCoordinator.mode)
            }
            .sheet(item: $viewModel.pendingPreviewPair) { request in
                PairPreviewView(pair: request.pair)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

struct HomeSheets: ViewModifier {
    @Bindable var viewModel: HomeViewModel

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "home_button_create_album"),
                isPresented: $viewModel.showCreateAlbum,
            ) {
                TextField(
                    HomeCreateAlbumPlaceholder.text(label: viewModel.resolvedAlbumLabel),
                    text: $viewModel.albumNameInput,
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.cancelCreateAlbum()
                }
                Button(String(localized: "common_button_create")) {
                    Task { await viewModel.confirmCreateAlbum() }
                }
            } message: {
                Text(String(localized: "home_dialog_album_create_hint"))
            }
            .task(id: viewModel.showCreateAlbum) {
                if viewModel.showCreateAlbum {
                    await viewModel.preloadAlbumLocation()
                }
            }
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

enum HomeCreateAlbumPlaceholder {
    static func text(label: String?) -> String {
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return String(localized: "home_dialog_album_create_placeholder")
        }
        return trimmed
    }
}
