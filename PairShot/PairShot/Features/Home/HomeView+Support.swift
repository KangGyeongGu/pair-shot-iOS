import SwiftData
import SwiftUI

struct HomeBottomBarHost: View {
    let viewModel: HomeViewModel
    let sortedPairs: [PhotoPair]
    let sortedAlbums: [Album]

    var body: some View {
        if viewModel.isSelectionMode {
            switch viewModel.contentMode {
                case .pairs:
                    HomePairSelectionBottomBar(
                        selectionCount: viewModel.selectedPairIds.count,
                        onShare: { viewModel.presentExport(from: sortedPairs) },
                        onSaveToDevice: { viewModel.presentExport(from: sortedPairs) },
                        onDelete: { viewModel.requestPairDeletion(from: sortedPairs) },
                        onExportSettings: { viewModel.presentExport(from: sortedPairs) }
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
                            ? String(localized: "촬영 시작")
                            : String(localized: "촬영"),
                        systemImage: "camera.fill"
                    ) { viewModel.startCapture() }

                case .albums:
                    HomePrimaryActionBar(
                        title: String(localized: "앨범 생성"),
                        systemImage: "plus.rectangle.on.rectangle"
                    ) { viewModel.openCreateAlbum() }
            }
        }
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
            .accessibilityLabel(String(localized: "선택 해제"))
        }
        ToolbarItem(placement: .principal) {
            Text(String(format: String(localized: "%d개 선택"), selectionCount))
                .font(.headline)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: toggleSelectAll) {
                Text(allSelected
                    ? String(localized: "전체해제")
                    : String(localized: "전체선택")
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
            .accessibilityLabel(String(localized: "선택 모드"))
            .disabled(viewModel == nil)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel?.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(String(localized: "설정"))
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
                NavigationStack { BeforeCameraView() }
            }
            .fullScreenCover(isPresented: $viewModel.showAfterCamera) {
                NavigationStack { AfterCameraView() }
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
                CreateAlbumDialog(isPresented: $viewModel.showCreateAlbum) { name, includeLocation in
                    await viewModel.createAlbum(name: name, includeLocation: includeLocation)
                }
            }
            .sheet(item: $viewModel.pendingExport) { payload in
                ExportPicker(pairs: payload.pairs, storage: viewModel.storage)
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
    }
}

struct HomeDeleteDialogs: ViewModifier {
    @Bindable var viewModel: HomeViewModel

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "페어 삭제"),
                isPresented: pairDeleteBinding,
                presenting: viewModel.pendingPairDelete
            ) { request in
                Button(String(localized: "일괄 삭제"), role: .destructive) {
                    Task {
                        await viewModel.confirmPairDeletion(mode: .wholePair, pairs: request.pairs)
                        viewModel.pendingPairDelete = nil
                    }
                }
                Button(String(localized: "합성본만"), role: .destructive) {
                    Task {
                        await viewModel.confirmPairDeletion(mode: .combinedOnly, pairs: request.pairs)
                        viewModel.pendingPairDelete = nil
                    }
                }
                Button(String(localized: "취소"), role: .cancel) {
                    viewModel.pendingPairDelete = nil
                }
            } message: { request in
                Text(String(format: String(localized: "%d개 선택"), request.pairs.count))
            }
            .confirmationDialog(
                String(localized: "앨범 삭제"),
                isPresented: albumDeleteBinding,
                presenting: viewModel.pendingAlbumDelete
            ) { request in
                Button(String(localized: "삭제"), role: .destructive) {
                    Task {
                        await viewModel.confirmAlbumDeletion(albums: request.albums)
                        viewModel.pendingAlbumDelete = nil
                    }
                }
                Button(String(localized: "취소"), role: .cancel) {
                    viewModel.pendingAlbumDelete = nil
                }
            } message: { _ in
                Text(String(localized: "앨범을 삭제하시겠습니까? 페어는 유지됩니다."))
            }
            .alert(
                String(localized: "페어 삭제"),
                isPresented: singlePairDeleteBinding,
                presenting: viewModel.pendingSinglePairDelete
            ) { request in
                Button(String(localized: "삭제"), role: .destructive) {
                    Task {
                        await viewModel.confirmSinglePairDeletion(request.pair)
                        viewModel.pendingSinglePairDelete = nil
                    }
                }
                Button(String(localized: "취소"), role: .cancel) {
                    viewModel.pendingSinglePairDelete = nil
                }
            } message: { _ in
                Text(String(localized: "이 페어를 삭제하시겠습니까?"))
            }
            .alert(
                String(localized: "앨범 삭제"),
                isPresented: singleAlbumDeleteBinding,
                presenting: viewModel.pendingSingleAlbumDelete
            ) { request in
                Button(String(localized: "삭제"), role: .destructive) {
                    Task {
                        await viewModel.confirmSingleAlbumDeletion(request.album)
                        viewModel.pendingSingleAlbumDelete = nil
                    }
                }
                Button(String(localized: "취소"), role: .cancel) {
                    viewModel.pendingSingleAlbumDelete = nil
                }
            } message: { _ in
                Text(String(localized: "앨범을 삭제하시겠습니까? 페어는 유지됩니다."))
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
                TextField(String(localized: "앨범 이름 입력"), text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .navigationTitle(String(localized: "앨범 이름 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "취소")) { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "저장")) {
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
