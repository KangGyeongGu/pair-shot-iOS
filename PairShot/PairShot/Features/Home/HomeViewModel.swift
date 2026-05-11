import CoreLocation
import Foundation
import Observation

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

struct HomePairPreviewRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

struct HomeRecaptureAfterRequest: Identifiable {
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
    var pendingRecaptureAfter: HomeRecaptureAfterRequest?
    var pendingPairDelete: HomePairDeleteRequest?
    var pendingAlbumDelete: HomeAlbumDeleteRequest?
    var pendingAlbumDestructive: HomeAlbumDeleteRequest?
    var pendingSinglePairDelete: HomeSinglePairDeleteRequest?
    var pendingSingleAlbumDelete: HomeSingleAlbumDeleteRequest?
    var pendingSingleAlbumDestructive: HomeSingleAlbumDeleteRequest?
    var pendingShareItems: ExportShareItems?
    var pendingZipExport: DocumentExporterItem?
    var isExporting: Bool = false

    var pendingZipProgress: SnackbarProgressHandle?
    var showCreateAlbum: Bool = false
    var albumNameInput: String = ""
    var resolvedAlbumLatitude: Double?
    var resolvedAlbumLongitude: Double?
    var resolvedAlbumLabel: String?

    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let deletePairs: DeletePairsUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase?
    let deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase?
    let toggleAlbumMembership: ToggleAlbumMembershipUseCase
    let location: CoreLocationService
    let thumbnailCache: PhotoLibraryThumbnailCache
    let immediateExport: ImmediateExportService
    let appSettings: AppSettings
    let interstitialAdManager: InterstitialAdManager?
    let adFreeStore: AdFreeStore?
    let fullscreenAdCoordinator: FullscreenAdCoordinator?

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
        deleteCombinedExports: DeleteCombinedExportsUseCase? = nil,
        deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase? = nil
    ) {
        self.pairRepo = pairRepo
        self.albumRepo = albumRepo
        self.deletePairs = deletePairs
        self.deleteCombinedExports = deleteCombinedExports
        self.deletePairsKeepingCombined = deletePairsKeepingCombined
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
        return
            grouped
                .map { (date: $0.key, pairs: $0.value) }
                .sorted { sortOrder == .newest ? $0.date > $1.date : $0.date < $1.date }
    }

    func sortedAlbums(from all: [Album]) -> [Album] {
        switch sortOrder {
            case .newest:
                all.sorted { $0.createdAt > $1.createdAt }

            case .oldest:
                all.sorted { $0.createdAt < $1.createdAt }
        }
    }

    func groupedAlbums(from all: [Album], calendar: Calendar = .current) -> [(date: Date, albums: [Album])] {
        let sorted = sortedAlbums(from: all)
        let grouped = Dictionary(grouping: sorted) { calendar.startOfDay(for: $0.createdAt) }
        return
            grouped
                .map { (date: $0.key, albums: $0.value) }
                .sorted { sortOrder == .newest ? $0.date > $1.date : $0.date < $1.date }
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
        beforeCameraTargetPairId = nil
        showBeforeCamera = true
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

    func requestAlbumDeletion(from all: [Album]) {
        let chosen = all.filter { selectedAlbumIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pendingAlbumDelete = HomeAlbumDeleteRequest(albums: chosen)
    }

    func requestSinglePairDeletion(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingSinglePairDelete = HomeSinglePairDeleteRequest(pair: pair)
    }

    func requestRecaptureAfter(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingRecaptureAfter = HomeRecaptureAfterRequest(pair: pair)
    }

    func requestSingleAlbumDeletion(_ album: Album) {
        guard !isSelectionMode else { return }
        pendingSingleAlbumDelete = HomeSingleAlbumDeleteRequest(album: album)
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
