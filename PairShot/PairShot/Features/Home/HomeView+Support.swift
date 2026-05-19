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
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                if isPro {
                    Text(verbatim: "Pro")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().stroke(Color.accentColor, lineWidth: 1),
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
            .paywallSheet(isPresented: $viewModel.showPaywall)
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
            .fullScreenCover(item: $viewModel.pendingRecaptureAfter) { request in
                NavigationStack {
                    AfterCameraView(recaptureTargetPair: request.pair)
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
                            set: { newValue in
                                if newValue == nil, viewModel.pendingZipExport != nil {
                                    viewModel.handleZipExportCompleted(false)
                                }
                            },
                        ),
                    ) { item in
                        DocumentExporter(url: item.url) { saved in
                            viewModel.handleZipExportCompleted(saved)
                        }
                    },
            )
    }
}

struct HomeDeleteDialogs: ViewModifier {
    @Bindable var viewModel: HomeViewModel

    private var pairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPairDelete != nil },
            set: { if !$0 { viewModel.pendingPairDelete = nil } },
        )
    }

    private var albumDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingAlbumDelete != nil },
            set: { if !$0 { viewModel.pendingAlbumDelete = nil } },
        )
    }

    private var albumDestructiveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingAlbumDestructive != nil },
            set: { if !$0 { viewModel.pendingAlbumDestructive = nil } },
        )
    }

    private var singlePairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSinglePairDelete != nil },
            set: { if !$0 { viewModel.pendingSinglePairDelete = nil } },
        )
    }

    private var singleAlbumDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSingleAlbumDelete != nil },
            set: { if !$0 { viewModel.pendingSingleAlbumDelete = nil } },
        )
    }

    private var singleAlbumDestructiveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSingleAlbumDestructive != nil },
            set: { if !$0 { viewModel.pendingSingleAlbumDestructive = nil } },
        )
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: pairDeleteBinding,
                presenting: viewModel.pendingPairDelete,
            ) { request in
                pairDeleteButtons(request: request)
            } message: { request in
                Text(String(format: String(localized: "home_topbar_selection_count_int"), request.pairs.count))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: albumDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingAlbumDelete,
            ) { request in
                albumDeleteButtons(request: request)
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: albumDestructiveBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingAlbumDestructive,
            ) { request in
                albumDestructiveButtons(request: request)
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: singlePairDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSinglePairDelete,
            ) { request in
                singlePairDeleteButtons(request: request)
            } message: { _ in
                Text(String(localized: "dialog_delete_pair_message"))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: singleAlbumDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSingleAlbumDelete,
            ) { request in
                singleAlbumDeleteButtons(request: request)
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: singleAlbumDestructiveBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSingleAlbumDestructive,
            ) { request in
                singleAlbumDestructiveButtons(request: request)
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
    }

    @ViewBuilder
    private func pairDeleteButtons(request: HomePairDeleteRequest) -> some View {
        Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
            Task {
                await viewModel.confirmPairDeletion(pairs: request.pairs)
                viewModel.pendingPairDelete = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
            Task {
                await viewModel.confirmOriginalOnlyPairDeletion(pairs: request.pairs)
                viewModel.pendingPairDelete = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
            Task {
                await viewModel.confirmCombinedDeletion(pairs: request.pairs)
                viewModel.pendingPairDelete = nil
            }
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingPairDelete = nil
        }
    }

    @ViewBuilder
    private func albumDeleteButtons(request: HomeAlbumDeleteRequest) -> some View {
        Button(String(localized: "album_delete_method_button_album_only")) {
            Task {
                await viewModel.confirmAlbumDeletion(albums: request.albums)
                viewModel.pendingAlbumDelete = nil
            }
        }
        Button(String(localized: "album_delete_method_button_with_pairs"), role: .destructive) {
            viewModel.pendingAlbumDestructive = request
            viewModel.pendingAlbumDelete = nil
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingAlbumDelete = nil
        }
    }

    @ViewBuilder
    private func albumDestructiveButtons(request: HomeAlbumDeleteRequest) -> some View {
        Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
            Task {
                await viewModel.confirmAlbumDeletionAllPairs(albums: request.albums)
                viewModel.pendingAlbumDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
            Task {
                await viewModel.confirmAlbumDeletionOriginalOnly(albums: request.albums)
                viewModel.pendingAlbumDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
            Task {
                await viewModel.confirmAlbumDeletionCombinedOnly(albums: request.albums)
                viewModel.pendingAlbumDestructive = nil
            }
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingAlbumDestructive = nil
        }
    }

    @ViewBuilder
    private func singlePairDeleteButtons(request: HomeSinglePairDeleteRequest) -> some View {
        Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
            Task {
                await viewModel.confirmSinglePairDeletion(request.pair)
                viewModel.pendingSinglePairDelete = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
            Task {
                await viewModel.confirmSingleOriginalOnlyPairDeletion(request.pair)
                viewModel.pendingSinglePairDelete = nil
            }
        }
        if request.pair.hasCombinedExport {
            Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
                Task {
                    await viewModel.confirmSingleCombinedDeletion(request.pair)
                    viewModel.pendingSinglePairDelete = nil
                }
            }
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingSinglePairDelete = nil
        }
    }

    @ViewBuilder
    private func singleAlbumDeleteButtons(request: HomeSingleAlbumDeleteRequest) -> some View {
        Button(String(localized: "album_delete_method_button_album_only")) {
            Task {
                await viewModel.confirmSingleAlbumDeletion(request.album)
                viewModel.pendingSingleAlbumDelete = nil
            }
        }
        Button(String(localized: "album_delete_method_button_with_pairs"), role: .destructive) {
            viewModel.pendingSingleAlbumDestructive = request
            viewModel.pendingSingleAlbumDelete = nil
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingSingleAlbumDelete = nil
        }
    }

    @ViewBuilder
    private func singleAlbumDestructiveButtons(request: HomeSingleAlbumDeleteRequest) -> some View {
        Button(String(localized: "dialog_delete_pair_button_all"), role: .destructive) {
            Task {
                await viewModel.confirmSingleAlbumDeletionAllPairs(request.album)
                viewModel.pendingSingleAlbumDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_original_only"), role: .destructive) {
            Task {
                await viewModel.confirmSingleAlbumDeletionOriginalOnly(request.album)
                viewModel.pendingSingleAlbumDestructive = nil
            }
        }
        Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
            Task {
                await viewModel.confirmSingleAlbumDeletionCombinedOnly(request.album)
                viewModel.pendingSingleAlbumDestructive = nil
            }
        }
        Button(String(localized: "common_button_cancel"), role: .cancel) {
            viewModel.pendingSingleAlbumDestructive = nil
        }
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
