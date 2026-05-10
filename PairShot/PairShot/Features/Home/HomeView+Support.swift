import SwiftUI

struct HomeBottomBarHost: View {
    let viewModel: HomeViewModel
    let sortedPairs: [PhotoPair]
    let sortedAlbums: [Album]
    let onPushExportSettings: (([UUID]) -> Void)?

    var body: some View {
        if viewModel.isSelectionMode {
            switch viewModel.contentMode {
                case .pairs:
                    HomePairSelectionBottomBar(
                        selectionCount: viewModel.selectedPairIds.count,
                        onShare: { Task { await viewModel.shareSelectedPairs(from: sortedPairs) } },
                        onSaveToDevice: { Task { await viewModel.saveSelectedPairsToDevice(from: sortedPairs) } },
                        onDelete: { viewModel.requestPairDeletion(from: sortedPairs) },
                        onExportSettings: pushExport
                    )

                case .albums:
                    HomePairSelectionBottomBar(
                        selectionCount: viewModel.selectedAlbumIds.count,
                        onShare: {
                            Task {
                                await viewModel.shareSelectedAlbumPairs(
                                    from: sortedAlbums,
                                    allPairs: sortedPairs
                                )
                            }
                        },
                        onSaveToDevice: {
                            Task {
                                await viewModel.saveSelectedAlbumPairsToDevice(
                                    from: sortedAlbums,
                                    allPairs: sortedPairs
                                )
                            }
                        },
                        onDelete: { viewModel.requestAlbumDeletion(from: sortedAlbums) },
                        onExportSettings: pushAlbumExport
                    )
            }
        } else {
            switch viewModel.contentMode {
                case .pairs:
                    HomePrimaryActionBar(
                        title: sortedPairs.isEmpty
                            ? String(localized: "common_button_start_capture")
                            : String(localized: "camera_desc_capture"),
                        systemImage: "camera.fill"
                    ) { viewModel.startCapture() }

                case .albums:
                    HomePrimaryActionBar(
                        title: String(localized: "home_button_create_album"),
                        systemImage: "plus.rectangle.on.rectangle"
                    ) { viewModel.openCreateAlbum() }
            }
        }
    }

    private func pushExport() {
        let chosen = sortedPairs
            .filter { viewModel.selectedPairIds.contains($0.id) }
            .map(\.id)
        guard !chosen.isEmpty else { return }
        onPushExportSettings?(chosen)
    }

    private func pushAlbumExport() {
        let pairIds = sortedAlbums
            .filter { viewModel.selectedAlbumIds.contains($0.id) }
            .flatMap(\.pairIds)
        let unique = Array(Set(pairIds))
        guard !unique.isEmpty else { return }
        onPushExportSettings?(unique)
    }
}

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
                Text(allSelected
                    ? String(localized: "home_button_deselect_all")
                    : String(localized: "home_button_select_all")
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

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(String(localized: "PairShot"))
                .font(.title3.weight(.semibold))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel?.enterSelectionMode()
            } label: {
                Image(systemName: "checkmark.circle")
            }
            .accessibilityLabel(String(localized: "home_desc_selection_mode"))
            .disabled(viewModel == nil)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                onPushSettings?()
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(String(localized: "common_label_settings"))
            .disabled(onPushSettings == nil)
        }
    }
}

struct HomeViewSheetModifiers: ViewModifier {
    let viewModel: HomeViewModel
    let sortedPairs: [PhotoPair]
    let sortedAlbums: [Album]

    func body(content: Content) -> some View {
        content
            .modifier(HomeCameraCovers(viewModel: viewModel))
            .modifier(HomeSheets(viewModel: viewModel))
            .modifier(HomeDeleteDialogs(viewModel: viewModel))
    }
}

struct HomeCameraCovers: ViewModifier {
    @Bindable var viewModel: HomeViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $viewModel.showBeforeCamera) {
                NavigationStack {
                    BeforeCameraView(refillPairId: viewModel.beforeCameraTargetPairId)
                }
            }
            .fullScreenCover(isPresented: $viewModel.showAfterCamera) {
                NavigationStack {
                    AfterCameraView(
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

struct HomeSheets: ViewModifier {
    @Bindable var viewModel: HomeViewModel

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "home_button_create_album"),
                isPresented: $viewModel.showCreateAlbum
            ) {
                TextField(
                    HomeCreateAlbumPlaceholder.text(label: viewModel.resolvedAlbumLabel),
                    text: $viewModel.albumNameInput
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

struct HomeDeleteDialogs: ViewModifier {
    @Bindable var viewModel: HomeViewModel

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: pairDeleteBinding,
                presenting: viewModel.pendingPairDelete
            ) { request in
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
            } message: { request in
                Text(String(format: String(localized: "home_topbar_selection_count_int"), request.pairs.count))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: albumDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingAlbumDelete
            ) { request in
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
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: albumDestructiveBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingAlbumDestructive
            ) { request in
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
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .confirmationDialog(
                String(localized: "dialog_delete_pair_title"),
                isPresented: singlePairDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSinglePairDelete
            ) { request in
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
            } message: { _ in
                Text(String(localized: "dialog_delete_pair_message"))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: singleAlbumDeleteBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSingleAlbumDelete
            ) { request in
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
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .confirmationDialog(
                String(localized: "album_dialog_delete_title"),
                isPresented: singleAlbumDestructiveBinding,
                titleVisibility: .visible,
                presenting: viewModel.pendingSingleAlbumDestructive
            ) { request in
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
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
    }

    private var pairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPairDelete != nil },
            set: { if !$0 { viewModel.pendingPairDelete = nil } }
        )
    }

    private var albumDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingAlbumDelete != nil },
            set: { if !$0 { viewModel.pendingAlbumDelete = nil } }
        )
    }

    private var albumDestructiveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingAlbumDestructive != nil },
            set: { if !$0 { viewModel.pendingAlbumDestructive = nil } }
        )
    }

    private var singlePairDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSinglePairDelete != nil },
            set: { if !$0 { viewModel.pendingSinglePairDelete = nil } }
        )
    }

    private var singleAlbumDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSingleAlbumDelete != nil },
            set: { if !$0 { viewModel.pendingSingleAlbumDelete = nil } }
        )
    }

    private var singleAlbumDestructiveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingSingleAlbumDestructive != nil },
            set: { if !$0 { viewModel.pendingSingleAlbumDestructive = nil } }
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
