import Foundation
import Observation
import SwiftData

enum HomeContentMode: String, CaseIterable, Identifiable {
    case pairs
    case albums

    var id: String {
        rawValue
    }
}

enum HomeSortOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest

    var id: String {
        rawValue
    }
}

struct HomePairDeleteRequest: Identifiable {
    let id = UUID()
    let pairs: [PhotoPair]
}

struct HomeAlbumDeleteRequest: Identifiable {
    let id = UUID()
    let albums: [Album]
}

struct HomeSinglePairDeleteRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

struct HomeSingleAlbumDeleteRequest: Identifiable {
    let id = UUID()
    let album: Album
}

struct HomeAlbumRenameRequest: Identifiable {
    let id = UUID()
    let album: Album
}

struct HomePairPreviewRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

@MainActor
@Observable
final class HomeViewModel {
    let storage: PhotoStorageService

    var contentMode: HomeContentMode = .pairs
    var sortOrder: HomeSortOrder {
        get { HomeSortOrderMapping.sortOrder(from: appSettings.homeSortOrder) }
        set { appSettings.homeSortOrder = HomeSortOrderMapping.persisted(from: newValue) }
    }

    var isSelectionMode: Bool = false
    var selectedPairIds: Set<UUID> = []
    var selectedAlbumIds: Set<UUID> = []

    var showBeforeCamera: Bool = false
    var showAfterCamera: Bool = false
    var afterCameraTargetPairId: UUID?
    var pendingPreviewPair: HomePairPreviewRequest?
    var pendingPairDelete: HomePairDeleteRequest?
    var pendingAlbumDelete: HomeAlbumDeleteRequest?
    var pendingSinglePairDelete: HomeSinglePairDeleteRequest?
    var pendingSingleAlbumDelete: HomeSingleAlbumDeleteRequest?
    var pendingAlbumRename: HomeAlbumRenameRequest?
    var pendingShareItems: ExportShareItems?
    var pendingZipExport: DocumentExporterItem?
    var isExporting: Bool = false

    private var pendingZipProgress: SnackbarProgressHandle?
    var showCreateAlbum: Bool = false
    var showSettings: Bool = false

    private let pairRepo: PhotoPairRepository
    private let albumRepo: AlbumRepository
    private let deletePairs: DeletePairsUseCase
    private let toggleAlbumMembership: ToggleAlbumMembershipUseCase
    private let location: LocationFetching
    private let thumbnailCache: ThumbnailCache
    private let immediateExport: ImmediateExportService
    private let appSettings: AppSettings
    private let interstitialAdManager: InterstitialAdManager?
    private let adFreeStore: AdFreeStore?
    private let fullscreenAdCoordinator: FullscreenAdCoordinator?

    init(
        pairRepo: PhotoPairRepository,
        albumRepo: AlbumRepository,
        deletePairs: DeletePairsUseCase,
        toggleAlbumMembership: ToggleAlbumMembershipUseCase,
        storage: PhotoStorageService,
        location: LocationFetching,
        immediateExport: ImmediateExportService,
        appSettings: AppSettings,
        thumbnailCache: ThumbnailCache = .shared,
        interstitialAdManager: InterstitialAdManager? = nil,
        adFreeStore: AdFreeStore? = nil,
        fullscreenAdCoordinator: FullscreenAdCoordinator? = nil
    ) {
        self.pairRepo = pairRepo
        self.albumRepo = albumRepo
        self.deletePairs = deletePairs
        self.toggleAlbumMembership = toggleAlbumMembership
        self.storage = storage
        self.location = location
        self.immediateExport = immediateExport
        self.appSettings = appSettings
        self.thumbnailCache = thumbnailCache
        self.interstitialAdManager = interstitialAdManager
        self.adFreeStore = adFreeStore
        self.fullscreenAdCoordinator = fullscreenAdCoordinator
    }

    func sortedPairs(from all: [PhotoPair]) -> [PhotoPair] {
        switch sortOrder {
            case .newest:
                all.sorted { $0.createdAt > $1.createdAt }

            case .oldest:
                all.sorted { $0.createdAt < $1.createdAt }
        }
    }

    func groupedPairs(from all: [PhotoPair], calendar: Calendar = .current) -> [(date: Date, pairs: [PhotoPair])] {
        let sorted = sortedPairs(from: all)
        let grouped = Dictionary(grouping: sorted) { calendar.startOfDay(for: $0.createdAt) }
        return grouped
            .map { (date: $0.key, pairs: $0.value) }
            .sorted { $0.date > $1.date }
    }

    func sortedAlbums(from all: [Album]) -> [Album] {
        switch sortOrder {
            case .newest:
                all.sorted { $0.updatedAt > $1.updatedAt }

            case .oldest:
                all.sorted { $0.updatedAt < $1.updatedAt }
        }
    }

    func setSortOrder(_ order: HomeSortOrder) {
        sortOrder = order
    }

    func switchContentMode(to mode: HomeContentMode) {
        guard mode != contentMode else { return }
        contentMode = mode
        cancelSelection()
    }

    func reload() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    func enterSelectionMode() {
        guard !isSelectionMode else { return }
        isSelectionMode = true
    }

    func cancelSelection() {
        isSelectionMode = false
        selectedPairIds.removeAll()
        selectedAlbumIds.removeAll()
    }

    func togglePairSelection(_ id: UUID) {
        if selectedPairIds.contains(id) {
            selectedPairIds.remove(id)
        } else {
            selectedPairIds.insert(id)
        }
    }

    func toggleAlbumSelection(_ id: UUID) {
        if selectedAlbumIds.contains(id) {
            selectedAlbumIds.remove(id)
        } else {
            selectedAlbumIds.insert(id)
        }
    }

    func longPressPair(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        isSelectionMode = true
        selectedPairIds = [pair.id]
    }

    func longPressAlbum(_ album: Album) {
        guard !isSelectionMode else { return }
        isSelectionMode = true
        selectedAlbumIds = [album.id]
    }

    func tapPair(_ pair: PhotoPair, allPairs _: [PhotoPair]) {
        if isSelectionMode {
            togglePairSelection(pair.id)
            return
        }
        if pair.afterFileName == nil {
            afterCameraTargetPairId = pair.id
            showAfterCamera = true
            return
        }
        pendingPreviewPair = HomePairPreviewRequest(pair: pair)
    }

    func tapAlbum(_ album: Album) {
        if isSelectionMode {
            toggleAlbumSelection(album.id)
        }
    }

    func selectAllPairs(from all: [PhotoPair]) {
        let allIds = Set(all.map(\.id))
        selectedPairIds = selectedPairIds == allIds ? [] : allIds
    }

    func selectAllAlbums(from all: [Album]) {
        let allIds = Set(all.map(\.id))
        selectedAlbumIds = selectedAlbumIds == allIds ? [] : allIds
    }

    func areAllPairsSelected(from all: [PhotoPair]) -> Bool {
        !all.isEmpty && selectedPairIds.count == all.count
    }

    func areAllAlbumsSelected(from all: [Album]) -> Bool {
        !all.isEmpty && selectedAlbumIds.count == all.count
    }

    func startCapture() {
        showBeforeCamera = true
    }

    func shareSelectedPairs(from all: [PhotoPair]) async {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        guard !isExporting else { return }
        await runWithInterstitial { [weak self] in
            await self?.performShare(pairs: chosen)
        }
    }

    func saveSelectedPairsToDevice(from all: [PhotoPair]) async {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        guard !isExporting else { return }
        await runWithInterstitial { [weak self] in
            await self?.performSaveToDevice(pairs: chosen)
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

    private func runWithInterstitial(_ work: @escaping @MainActor () async -> Void) async {
        guard
            let interstitialAdManager,
            let adFreeStore,
            let fullscreenAdCoordinator
        else {
            await work()
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task { @MainActor in
                await interstitialAdManager.showIfAvailable(
                    from: BannerAdView.resolveTopPresentedViewController(),
                    adFreeStore: adFreeStore,
                    coordinator: fullscreenAdCoordinator
                ) {
                    Task { @MainActor in
                        await work()
                        continuation.resume()
                    }
                }
            }
        }
    }

    func clearShareItems() {
        if let items = pendingShareItems {
            immediateExport.cleanup(items: items)
        }
        pendingShareItems = nil
        cancelSelection()
    }

    func openCreateAlbum() {
        showCreateAlbum = true
    }

    func openSettings() {
        showSettings = true
    }

    func requestPairDeletion(from all: [PhotoPair]) {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pendingPairDelete = HomePairDeleteRequest(pairs: chosen)
    }

    func requestAlbumDeletion(from all: [Album]) {
        let chosen = all.filter { selectedAlbumIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pendingAlbumDelete = HomeAlbumDeleteRequest(albums: chosen)
    }

    func requestSinglePairDeletion(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingSinglePairDelete = HomeSinglePairDeleteRequest(pair: pair)
    }

    func requestSingleAlbumDeletion(_ album: Album) {
        guard !isSelectionMode else { return }
        pendingSingleAlbumDelete = HomeSingleAlbumDeleteRequest(album: album)
    }

    func requestAlbumRename(from all: [Album]) {
        guard selectedAlbumIds.count == 1,
              let id = selectedAlbumIds.first,
              let album = all.first(where: { $0.id == id })
        else { return }
        pendingAlbumRename = HomeAlbumRenameRequest(album: album)
    }

    func confirmPairDeletion(mode: DeletePairsUseCase.Mode, pairs: [PhotoPair]) async {
        let snapshots = pairs.map { pair in
            EvictionSnapshot(
                beforeFileName: pair.beforeFileName,
                afterFileName: pair.afterFileName,
                combinedFileName: pair.combinedFileName
            )
        }
        let ids = Set(pairs.map(\.id))
        try? await deletePairs(ids: ids, mode: mode)
        for snapshot in snapshots {
            evictThumbnails(for: snapshot, mode: mode)
        }
        cancelSelection()
    }

    func confirmSinglePairDeletion(_ pair: PhotoPair) async {
        let snapshot = EvictionSnapshot(
            beforeFileName: pair.beforeFileName,
            afterFileName: pair.afterFileName,
            combinedFileName: pair.combinedFileName
        )
        try? await deletePairs(ids: [pair.id], mode: .wholePair)
        evictThumbnails(for: snapshot, mode: .wholePair)
    }

    func confirmAlbumDeletion(albums: [Album]) async {
        for album in albums {
            try? await albumRepo.delete(id: album.id)
        }
        cancelSelection()
    }

    func confirmSingleAlbumDeletion(_ album: Album) async {
        try? await albumRepo.delete(id: album.id)
    }

    func renameAlbum(_ album: Album, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        album.name = trimmed
        album.updatedAt = .now
        try? await albumRepo.update(album)
        cancelSelection()
    }

    func createAlbum(
        name: String,
        latitude: Double?,
        longitude: Double?,
        locationLabel: String?
    ) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let album = Album(
            name: trimmed,
            latitude: latitude,
            longitude: longitude,
            locationLabel: locationLabel
        )
        try? await albumRepo.add(album)
    }

    private func evictThumbnails(for snapshot: EvictionSnapshot, mode: DeletePairsUseCase.Mode) {
        switch mode {
            case .wholePair:
                thumbnailCache.evict(beforeFileName: snapshot.beforeFileName)
                if let after = snapshot.afterFileName {
                    thumbnailCache.evict(afterFileName: after)
                }
                if let combined = snapshot.combinedFileName {
                    thumbnailCache.evict(combinedFileName: combined)
                }

            case .combinedOnly:
                if let combined = snapshot.combinedFileName {
                    thumbnailCache.evict(combinedFileName: combined)
                }
        }
    }

    deinit {}
}

private struct EvictionSnapshot {
    let beforeFileName: String
    let afterFileName: String?
    let combinedFileName: String?
}

nonisolated enum HomeSortOrderMapping {
    static func sortOrder(from raw: String) -> HomeSortOrder {
        switch raw.uppercased() {
            case SortOrderPersistence.ascending:
                .oldest

            default:
                .newest
        }
    }

    static func persisted(from order: HomeSortOrder) -> String {
        switch order {
            case .newest:
                SortOrderPersistence.descending

            case .oldest:
                SortOrderPersistence.ascending
        }
    }
}
