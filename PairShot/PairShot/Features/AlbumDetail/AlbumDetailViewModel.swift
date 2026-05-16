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
    var showPaywall: Bool = false

    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let deletePairs: DeletePairsUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase
    let deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase
    let thumbnailCache: PhotoLibraryThumbnailCache
    let immediateExport: ImmediateExportService
    let appSettings: AppSettings
    let interstitialAdManager: InterstitialAdManager
    let membership: Membership
    let fullscreenAdCoordinator: FullscreenAdCoordinator
    let snackbarQueue: SnackbarQueue

    init(
        albumId: UUID,
        pairRepo: PhotoPairRepository,
        albumRepo: AlbumRepository,
        deletePairs: DeletePairsUseCase,
        immediateExport: ImmediateExportService,
        appSettings: AppSettings,
        thumbnailCache: PhotoLibraryThumbnailCache,
        interstitialAdManager: InterstitialAdManager,
        membership: Membership,
        fullscreenAdCoordinator: FullscreenAdCoordinator,
        deleteCombinedExports: DeleteCombinedExportsUseCase,
        deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase,
        snackbarQueue: SnackbarQueue
    ) {
        self.albumId = albumId
        self.pairRepo = pairRepo
        self.albumRepo = albumRepo
        self.deletePairs = deletePairs
        self.deleteCombinedExports = deleteCombinedExports
        self.deletePairsKeepingCombined = deletePairsKeepingCombined
        self.immediateExport = immediateExport
        self.appSettings = appSettings
        self.thumbnailCache = thumbnailCache
        self.interstitialAdManager = interstitialAdManager
        self.membership = membership
        self.fullscreenAdCoordinator = fullscreenAdCoordinator
        self.snackbarQueue = snackbarQueue
    }

    func reload() async {}

    func longPressPair(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        isSelectionMode = true
        selectedPairIds = [pair.id]
    }

    func startPairPicker() {
        navigateToPairPicker = true
    }

    func removeFromAlbum(pairs: [PhotoPair]) async {
        for pair in pairs {
            try? await albumRepo.removePair(pairId: pair.id, fromAlbum: albumId)
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
        try? await albumRepo.update(updated)
    }
}
