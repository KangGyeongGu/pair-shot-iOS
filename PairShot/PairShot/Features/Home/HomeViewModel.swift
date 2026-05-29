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

@MainActor
@Observable
final class HomeViewModel {
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
    var pendingPreviewPair: PairPreviewRequest?
    var pendingAfterDelete: PairAfterDeleteRequest?
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
    var showPaywall: Bool = false
    var didAutoResumeAfterCamera: Bool = false

    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let deletePairs: DeletePairsUseCase
    let deleteAfterPhoto: DeleteAfterPhotoUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase
    let deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase
    let location: CoreLocationService
    let thumbnailCache: PhotoLibraryThumbnailCache
    let immediateExport: ImmediateExportService
    let appSettings: AppSettings
    let interstitialAdManager: InterstitialAdManager
    let membership: Membership
    let fullscreenAdCoordinator: FullscreenAdCoordinator
    let snackbarQueue: SnackbarQueue

    init(
        pairRepo: PhotoPairRepository,
        albumRepo: AlbumRepository,
        deletePairs: DeletePairsUseCase,
        deleteAfterPhoto: DeleteAfterPhotoUseCase,
        location: CoreLocationService,
        immediateExport: ImmediateExportService,
        appSettings: AppSettings,
        thumbnailCache: PhotoLibraryThumbnailCache,
        interstitialAdManager: InterstitialAdManager,
        membership: Membership,
        fullscreenAdCoordinator: FullscreenAdCoordinator,
        deleteCombinedExports: DeleteCombinedExportsUseCase,
        deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase,
        snackbarQueue: SnackbarQueue,
    ) {
        self.pairRepo = pairRepo
        self.albumRepo = albumRepo
        self.deletePairs = deletePairs
        self.deleteAfterPhoto = deleteAfterPhoto
        self.deleteCombinedExports = deleteCombinedExports
        self.deletePairsKeepingCombined = deletePairsKeepingCombined
        self.location = location
        self.immediateExport = immediateExport
        self.appSettings = appSettings
        self.thumbnailCache = thumbnailCache
        self.interstitialAdManager = interstitialAdManager
        self.membership = membership
        self.fullscreenAdCoordinator = fullscreenAdCoordinator
        self.snackbarQueue = snackbarQueue
    }

    func reload() async {}
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
