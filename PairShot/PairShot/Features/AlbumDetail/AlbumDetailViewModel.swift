import Foundation
import Observation

struct AlbumDetailPairDeleteRequest: Identifiable {
    let id = UUID()
    let pairs: [PhotoPair]
}

struct AlbumDetailSinglePairDeleteRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

struct AlbumDetailPairPreviewRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

struct AlbumDetailRecaptureAfterRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

@MainActor
@Observable
final class AlbumDetailViewModel {
    let albumId: UUID
    let photoLibrary: PhotoLibraryService

    var sortOrder: HomeSortOrder {
        get { HomeSortOrderMapping.sortOrder(from: appSettings.albumSortOrder) }
        set { appSettings.albumSortOrder = HomeSortOrderMapping.persisted(from: newValue) }
    }

    var isSelectionMode: Bool = false
    var selectedPairIds: Set<UUID> = []

    var showRenameAlert: Bool = false
    var renameDraft: String = ""
    var pendingAlbumDelete: Album?
    var pendingAlbumDestructive: Album?
    var albumDeleted: Bool = false

    var pendingPairDelete: AlbumDetailPairDeleteRequest?
    var pendingSinglePairDelete: AlbumDetailSinglePairDeleteRequest?
    var pendingPairDestructive: AlbumDetailPairDeleteRequest?
    var pendingSinglePairDestructive: AlbumDetailSinglePairDeleteRequest?
    var pendingPreviewPair: AlbumDetailPairPreviewRequest?
    var pendingRecaptureAfter: AlbumDetailRecaptureAfterRequest?
    var pendingShareItems: ExportShareItems?
    var pendingZipExport: DocumentExporterItem?
    var isExporting: Bool = false

    var pendingZipProgress: SnackbarProgressHandle?

    var showBeforeCamera: Bool = false
    var showAfterCamera: Bool = false
    var afterCameraTargetPairId: UUID?
    var beforeCameraTargetPairId: UUID?
    var navigateToPairPicker: Bool = false

    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let deletePairs: DeletePairsUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase?
    let deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase?
    let toggleAlbumMembership: ToggleAlbumMembershipUseCase
    let thumbnailCache: PhotoLibraryThumbnailCache
    let immediateExport: ImmediateExportService
    let appSettings: AppSettings
    let interstitialAdManager: InterstitialAdManager?
    let adFreeStore: AdFreeStore?
    let fullscreenAdCoordinator: FullscreenAdCoordinator?

    init(
        albumId: UUID,
        pairRepo: PhotoPairRepository,
        albumRepo: AlbumRepository,
        deletePairs: DeletePairsUseCase,
        toggleAlbumMembership: ToggleAlbumMembershipUseCase,
        photoLibrary: PhotoLibraryService,
        immediateExport: ImmediateExportService,
        appSettings: AppSettings,
        thumbnailCache: PhotoLibraryThumbnailCache,
        interstitialAdManager: InterstitialAdManager? = nil,
        adFreeStore: AdFreeStore? = nil,
        fullscreenAdCoordinator: FullscreenAdCoordinator? = nil,
        deleteCombinedExports: DeleteCombinedExportsUseCase? = nil,
        deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase? = nil
    ) {
        self.albumId = albumId
        self.pairRepo = pairRepo
        self.albumRepo = albumRepo
        self.deletePairs = deletePairs
        self.deleteCombinedExports = deleteCombinedExports
        self.deletePairsKeepingCombined = deletePairsKeepingCombined
        self.toggleAlbumMembership = toggleAlbumMembership
        self.photoLibrary = photoLibrary
        self.immediateExport = immediateExport
        self.appSettings = appSettings
        self.thumbnailCache = thumbnailCache
        self.interstitialAdManager = interstitialAdManager
        self.adFreeStore = adFreeStore
        self.fullscreenAdCoordinator = fullscreenAdCoordinator
    }

    func sortedPairs(from pairs: [PhotoPair]) -> [PhotoPair] {
        switch sortOrder {
            case .newest:
                pairs.sorted { $0.createdAt > $1.createdAt }

            case .oldest:
                pairs.sorted { $0.createdAt < $1.createdAt }
        }
    }

    func setSortOrder(_ order: HomeSortOrder) {
        sortOrder = order
    }

    func reload() async {}

    func enterSelectionMode() {
        guard !isSelectionMode else { return }
        isSelectionMode = true
    }

    func cancelSelection() {
        isSelectionMode = false
        selectedPairIds.removeAll()
    }

    func togglePairSelection(_ id: UUID) {
        if selectedPairIds.contains(id) {
            selectedPairIds.remove(id)
        } else {
            selectedPairIds.insert(id)
        }
    }

    func longPressPair(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        isSelectionMode = true
        selectedPairIds = [pair.id]
    }

    func tapPair(_ pair: PhotoPair, allPairs _: [PhotoPair]) {
        if isSelectionMode {
            togglePairSelection(pair.id)
            return
        }
        switch pair.status {
            case .afterOnly:
                beforeCameraTargetPairId = pair.id
                showBeforeCamera = true

            case .scheduled:
                afterCameraTargetPairId = pair.id
                showAfterCamera = true

            case .captured:
                pendingPreviewPair = AlbumDetailPairPreviewRequest(pair: pair)
        }
    }

    func selectAllPairs(from all: [PhotoPair]) {
        let allIds = Set(all.map(\.id))
        selectedPairIds = selectedPairIds == allIds ? [] : allIds
    }

    func areAllPairsSelected(from all: [PhotoPair]) -> Bool {
        !all.isEmpty && selectedPairIds.count == all.count
    }

    func startCapture() {
        beforeCameraTargetPairId = nil
        showBeforeCamera = true
    }

    func startPairPicker() {
        navigateToPairPicker = true
    }

    func shareSelectedPairs(from all: [PhotoPair]) async {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        guard !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            adFreeStore: adFreeStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performShare(pairs: chosen)
        }
    }

    func saveSelectedPairsToDevice(from all: [PhotoPair]) async {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        guard !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            adFreeStore: adFreeStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performSaveToDevice(pairs: chosen)
        }
    }

    func sharePair(_ pair: PhotoPair) async {
        guard !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            adFreeStore: adFreeStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performShare(pairs: [pair])
        }
    }

    func exportPair(_ pair: PhotoPair) async {
        guard !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            adFreeStore: adFreeStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performSaveToDevice(pairs: [pair])
        }
    }

    private func performShare(pairs: [PhotoPair]) async {
        isExporting = true
        defer { isExporting = false }
        do {
            let items = try await immediateExport.makeShareItems(for: pairs)
            guard !items.values.isEmpty else { return }
            pendingShareItems = items
        } catch {
            immediateExport.notifyShareFailure()
        }
    }

    private func performSaveToDevice(pairs: [PhotoPair]) async {
        isExporting = true
        defer { isExporting = false }
        let outcome = await immediateExport.saveToDevice(pairs: pairs)
        switch outcome {
            case .completed:
                cancelSelection()

            case let .zipPendingExport(url, progress):
                pendingZipProgress = progress
                pendingZipExport = DocumentExporterItem(url: url)
        }
    }

    func handleZipExportCompleted(_ saved: Bool) {
        let url = pendingZipExport?.url
        let progress = pendingZipProgress
        pendingZipExport = nil
        pendingZipProgress = nil
        if let url, let progress {
            immediateExport.finishZipExport(url: url, progress: progress, saved: saved)
            cancelSelection()
        }
    }

    func clearShareItems() {
        if let items = pendingShareItems {
            immediateExport.cleanup(items: items)
        }
        pendingShareItems = nil
        cancelSelection()
    }

    func requestPairDeletion(from all: [PhotoPair]) {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pendingPairDelete = AlbumDetailPairDeleteRequest(pairs: chosen)
    }

    func requestSinglePairDeletion(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingSinglePairDelete = AlbumDetailSinglePairDeleteRequest(pair: pair)
    }

    func requestRecaptureAfter(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingRecaptureAfter = AlbumDetailRecaptureAfterRequest(pair: pair)
    }

    func removeFromAlbum(pairs: [PhotoPair]) async {
        for pair in pairs {
            try? await toggleAlbumMembership(
                pairId: pair.id,
                albumId: albumId,
                isIncluded: false
            )
        }
        cancelSelection()
    }

    func beginRename(currentName: String) {
        renameDraft = currentName
        showRenameAlert = true
    }

    func confirmRename(album: Album) async {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = album
        updated.name = trimmed
        updated.updatedAt = .now
        try? await albumRepo.update(updated)
    }

    func requestAlbumDeletion(album: Album) {
        pendingAlbumDelete = album
    }
}
