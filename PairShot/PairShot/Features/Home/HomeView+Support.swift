import SwiftData
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
                    HomeAlbumSelectionBottomBar(
                        selectionCount: viewModel.selectedAlbumIds.count,
                        onRename: { viewModel.requestAlbumRename(from: sortedAlbums) },
                        onDelete: { viewModel.requestAlbumDeletion(from: sortedAlbums) }
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
                viewModel?.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(String(localized: "common_label_settings"))
            .disabled(viewModel == nil)
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
                        retakeMode: viewModel.afterCameraTargetPairId != nil,
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

struct HomeSheets: ViewModifier {
    @Bindable var viewModel: HomeViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showSettings) { SettingsView() }
            .sheet(isPresented: $viewModel.showCreateAlbum) {
                CreateAlbumDialog(isPresented: $viewModel.showCreateAlbum) { name, latitude, longitude, label in
                    await viewModel.createAlbum(
                        name: name,
                        latitude: latitude,
                        longitude: longitude,
                        locationLabel: label
                    )
                }
            }
            .sheet(item: $viewModel.pendingAlbumRename) { request in
                AlbumRenameDialog(
                    album: request.album,
                    isPresented: Binding(
                        get: { viewModel.pendingAlbumRename != nil },
                        set: { if !$0 { viewModel.pendingAlbumRename = nil } }
                    )
                ) { newName in
                    await viewModel.renameAlbum(request.album, to: newName)
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
                        await viewModel.confirmPairDeletion(mode: .wholePair, pairs: request.pairs)
                        viewModel.pendingPairDelete = nil
                    }
                }
                Button(String(localized: "dialog_delete_pair_button_combined_only"), role: .destructive) {
                    Task {
                        await viewModel.confirmPairDeletion(mode: .combinedOnly, pairs: request.pairs)
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
                presenting: viewModel.pendingAlbumDelete
            ) { request in
                Button(String(localized: "common_button_delete"), role: .destructive) {
                    Task {
                        await viewModel.confirmAlbumDeletion(albums: request.albums)
                        viewModel.pendingAlbumDelete = nil
                    }
                }
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.pendingAlbumDelete = nil
                }
            } message: { _ in
                Text(String(localized: "album_dialog_delete_message"))
            }
            .alert(
                String(localized: "dialog_delete_pair_title"),
                isPresented: singlePairDeleteBinding,
                presenting: viewModel.pendingSinglePairDelete
            ) { request in
                Button(String(localized: "common_button_delete"), role: .destructive) {
                    Task {
                        await viewModel.confirmSinglePairDeletion(request.pair)
                        viewModel.pendingSinglePairDelete = nil
                    }
                }
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.pendingSinglePairDelete = nil
                }
            } message: { _ in
                Text(String(localized: "dialog_delete_pair_message"))
            }
            .alert(
                String(localized: "album_dialog_delete_title"),
                isPresented: singleAlbumDeleteBinding,
                presenting: viewModel.pendingSingleAlbumDelete
            ) { request in
                Button(String(localized: "common_button_delete"), role: .destructive) {
                    Task {
                        await viewModel.confirmSingleAlbumDeletion(request.album)
                        viewModel.pendingSingleAlbumDelete = nil
                    }
                }
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.pendingSingleAlbumDelete = nil
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
}

struct AlbumRenameDialog: View {
    let album: Album
    @Binding var isPresented: Bool
    let onCommit: (String) async -> Void

    @State private var name: String

    init(album: Album, isPresented: Binding<Bool>, onCommit: @escaping (String) async -> Void) {
        self.album = album
        _isPresented = isPresented
        self.onCommit = onCommit
        _name = State(initialValue: album.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "album_dialog_rename_placeholder"), text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .navigationTitle(String(localized: "album_dialog_rename_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_button_cancel")) { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common_button_save")) {
                        Task {
                            await onCommit(name)
                            isPresented = false
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
