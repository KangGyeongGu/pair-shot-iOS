import CoreLocation
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
    let albums: [AlbumEntity]
}

struct HomeSinglePairDeleteRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

struct HomeSingleAlbumDeleteRequest: Identifiable {
    let id = UUID()
    let album: AlbumEntity
}

struct HomeAlbumRenameRequest: Identifiable {
    let id = UUID()
    let album: AlbumEntity
}

struct HomePairPreviewRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

@MainActor
@Observable
final class HomeViewModel {
    let photoLibrary: PhotoLibraryService

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
    var beforeCameraTargetPairId: UUID?
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
    var albumNameInput: String = ""
    var resolvedAlbumLatitude: Double?
    var resolvedAlbumLongitude: Double?
    var resolvedAlbumLabel: String?

    private let pairRepo: PhotoPairRepository
    private let albumRepo: AlbumRepository
    private let deletePairs: DeletePairsUseCase
    private let deleteCombinedExports: DeleteCombinedExportsUseCase?
    private let toggleAlbumMembership: ToggleAlbumMembershipUseCase
    private let location: CoreLocationService
    private let thumbnailCache: PhotoLibraryThumbnailCache
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
        photoLibrary: PhotoLibraryService,
        location: CoreLocationService,
        immediateExport: ImmediateExportService,
        appSettings: AppSettings,
        thumbnailCache: PhotoLibraryThumbnailCache,
        interstitialAdManager: InterstitialAdManager? = nil,
        adFreeStore: AdFreeStore? = nil,
        fullscreenAdCoordinator: FullscreenAdCoordinator? = nil,
        deleteCombinedExports: DeleteCombinedExportsUseCase? = nil
    ) {
        self.pairRepo = pairRepo
        self.albumRepo = albumRepo
        self.deletePairs = deletePairs
        self.deleteCombinedExports = deleteCombinedExports
        self.toggleAlbumMembership = toggleAlbumMembership
        self.photoLibrary = photoLibrary
        self.location = location
        self.immediateExport = immediateExport
        self.appSettings = appSettings
        self.thumbnailCache = thumbnailCache
        self.interstitialAdManager = interstitialAdManager
        self.adFreeStore = adFreeStore
        self.fullscreenAdCoordinator = fullscreenAdCoordinator
    }

    func deleteCombinedExports(for pair: PhotoPair) async {
        guard let useCase = deleteCombinedExports else { return }
        try? await useCase(ids: [pair.id])
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
            .sorted { sortOrder == .newest ? $0.date > $1.date : $0.date < $1.date }
    }

    func sortedAlbums(from all: [AlbumEntity]) -> [AlbumEntity] {
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

    func reload() async {}

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

    func longPressAlbum(_ album: AlbumEntity) {
        guard !isSelectionMode else { return }
        isSelectionMode = true
        selectedAlbumIds = [album.id]
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
                pendingPreviewPair = HomePairPreviewRequest(pair: pair)
        }
    }

    func tapAlbum(_ album: AlbumEntity) {
        if isSelectionMode {
            toggleAlbumSelection(album.id)
        }
    }

    func selectAllPairs(from all: [PhotoPair]) {
        let allIds = Set(all.map(\.id))
        selectedPairIds = selectedPairIds == allIds ? [] : allIds
    }

    func selectAllAlbums(from all: [AlbumEntity]) {
        let allIds = Set(all.map(\.id))
        selectedAlbumIds = selectedAlbumIds == allIds ? [] : allIds
    }

    func areAllPairsSelected(from all: [PhotoPair]) -> Bool {
        !all.isEmpty && selectedPairIds.count == all.count
    }

    func areAllAlbumsSelected(from all: [AlbumEntity]) -> Bool {
        !all.isEmpty && selectedAlbumIds.count == all.count
    }

    func startCapture() {
        beforeCameraTargetPairId = nil
        showBeforeCamera = true
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

    func openCreateAlbum() {
        albumNameInput = ""
        resolvedAlbumLatitude = nil
        resolvedAlbumLongitude = nil
        resolvedAlbumLabel = nil
        showCreateAlbum = true
    }

    func preloadAlbumLocation() async {
        guard resolvedAlbumLatitude == nil, resolvedAlbumLongitude == nil else { return }
        guard let coord = await location.fetchOnce() else { return }
        resolvedAlbumLatitude = coord.latitude
        resolvedAlbumLongitude = coord.longitude
        resolvedAlbumLabel = await HomeReverseGeocoder.label(latitude: coord.latitude, longitude: coord.longitude)
    }

    func confirmCreateAlbum() async {
        let trimmed = albumNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = resolvedAlbumLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalName = trimmed.isEmpty ? fallback : trimmed
        guard !finalName.isEmpty else {
            resetCreateAlbumState()
            return
        }
        await createAlbum(
            name: finalName,
            latitude: resolvedAlbumLatitude,
            longitude: resolvedAlbumLongitude,
            locationLabel: resolvedAlbumLabel
        )
        resetCreateAlbumState()
    }

    func cancelCreateAlbum() {
        resetCreateAlbumState()
    }

    private func resetCreateAlbumState() {
        albumNameInput = ""
        resolvedAlbumLatitude = nil
        resolvedAlbumLongitude = nil
        resolvedAlbumLabel = nil
    }

    func requestPairDeletion(from all: [PhotoPair]) {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pendingPairDelete = HomePairDeleteRequest(pairs: chosen)
    }

    func requestAlbumDeletion(from all: [AlbumEntity]) {
        let chosen = all.filter { selectedAlbumIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pendingAlbumDelete = HomeAlbumDeleteRequest(albums: chosen)
    }

    func requestSinglePairDeletion(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingSinglePairDelete = HomeSinglePairDeleteRequest(pair: pair)
    }

    func requestSingleAlbumDeletion(_ album: AlbumEntity) {
        guard !isSelectionMode else { return }
        pendingSingleAlbumDelete = HomeSingleAlbumDeleteRequest(album: album)
    }

    func requestAlbumRename(from all: [AlbumEntity]) {
        guard selectedAlbumIds.count == 1,
              let id = selectedAlbumIds.first,
              let album = all.first(where: { $0.id == id })
        else { return }
        pendingAlbumRename = HomeAlbumRenameRequest(album: album)
    }

    func confirmPairDeletion(pairs: [PhotoPair]) async {
        let snapshots: [(before: String?, after: String?)] = pairs.map {
            ($0.beforePhotoLocalIdentifier, $0.afterPhotoLocalIdentifier)
        }
        let ids = Set(pairs.map(\.id))
        try? await deletePairs(ids: ids)
        for snapshot in snapshots {
            evictThumbnails(beforeIdentifier: snapshot.before, afterIdentifier: snapshot.after)
        }
        cancelSelection()
    }

    func confirmCombinedDeletion(pairs: [PhotoPair]) async {
        guard let useCase = deleteCombinedExports else { return }
        let ids = Set(pairs.map(\.id))
        try? await useCase(ids: ids)
        cancelSelection()
    }

    func confirmSinglePairDeletion(_ pair: PhotoPair) async {
        let beforeId = pair.beforePhotoLocalIdentifier
        let afterId = pair.afterPhotoLocalIdentifier
        try? await deletePairs(ids: [pair.id])
        evictThumbnails(beforeIdentifier: beforeId, afterIdentifier: afterId)
    }

    func confirmAlbumDeletion(albums: [AlbumEntity]) async {
        for album in albums {
            try? await albumRepo.delete(id: album.id)
        }
        cancelSelection()
    }

    func confirmSingleAlbumDeletion(_ album: AlbumEntity) async {
        try? await albumRepo.delete(id: album.id)
    }

    func renameAlbum(_ album: AlbumEntity, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        album.name = trimmed
        album.updatedAt = .now
        let domain = Album(
            id: album.id,
            name: album.name,
            latitude: album.latitude,
            longitude: album.longitude,
            locationLabel: album.locationLabel,
            createdAt: album.createdAt,
            updatedAt: album.updatedAt,
            pairIds: album.pairs.map(\.id)
        )
        try? await albumRepo.update(domain)
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

    private func evictThumbnails(beforeIdentifier: String?, afterIdentifier: String?) {
        if let beforeIdentifier {
            thumbnailCache.evict(localIdentifier: beforeIdentifier)
        }
        if let afterIdentifier {
            thumbnailCache.evict(localIdentifier: afterIdentifier)
        }
    }
}

enum HomeReverseGeocoder {
    static func label(latitude: Double, longitude: Double) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location, preferredLocale: .current),
              let placemark = placemarks.first
        else { return nil }
        let raw = [
            placemark.locality,
            placemark.subLocality,
            placemark.thoroughfare,
            placemark.name,
        ].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        var seen: [String] = []
        for part in raw {
            if seen.contains(part) { continue }
            if let last = seen.last, part.contains(last) || last.contains(part) {
                if part.count > last.count {
                    seen[seen.count - 1] = part
                }
                continue
            }
            seen.append(part)
        }
        let combined = seen.joined(separator: " ")
        return combined.isEmpty ? nil : combined
    }
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
