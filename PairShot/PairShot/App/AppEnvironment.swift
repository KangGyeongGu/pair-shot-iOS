import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppEnvironment {
    let modelContainer: ModelContainer

    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository

    let location: CoreLocationService
    let zipExporter: ZipExporterAdapter
    let photoLibraryExporter: PhotoLibraryExport
    let photoLibrary: PhotoLibraryService
    let photoLibrarySync: PhotoLibrarySyncService

    let createPair: CreatePairUseCase
    let captureAfter: CaptureAfterUseCase
    let deletePairs: DeletePairsUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase
    let deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase
    let exportPairs: ExportPairsUseCase
    let toggleAlbumMembership: ToggleAlbumMembershipUseCase

    let appSettings: AppSettings
    let appSettingsRepo: AppSettingsRepository
    let trackingService: TrackingAuthorizationService

    let interstitialAdManager: InterstitialAdManager
    let rewardedAdManager: RewardedAdManager
    let nativeAdLoader: NativeAdLoader
    let appOpenAdManager: AppOpenAdManager
    let fullscreenAdCoordinator: FullscreenAdCoordinator

    let snackbarQueue: SnackbarQueue
    let immediateExport: ImmediateExportService
    let settingsRedirectCoordinator: SettingsRedirectCoordinator
    let permissionStatusService: PermissionStatusService
    let thumbnailCache: PhotoLibraryThumbnailCache
    let hapticService: HapticService
    let motionService: MotionService

    private var sharedSettingsViewModel: SettingsViewModel?

    init(
        modelContainer: ModelContainer,
        appSettings: AppSettings? = nil,
        appSettingsRepo: AppSettingsRepository? = nil,
        trackingService: TrackingAuthorizationService? = nil,
        interstitialAdManager: InterstitialAdManager? = nil,
        rewardedAdManager: RewardedAdManager? = nil,
        nativeAdLoader: NativeAdLoader? = nil,
        appOpenAdManager: AppOpenAdManager? = nil,
        fullscreenAdCoordinator: FullscreenAdCoordinator? = nil,
        snackbarQueue: SnackbarQueue? = nil,
        settingsRedirectCoordinator: SettingsRedirectCoordinator? = nil,
        permissionStatusService: PermissionStatusService? = nil,
        thumbnailCache: PhotoLibraryThumbnailCache? = nil,
        hapticService: HapticService? = nil,
        motionService: MotionService? = nil
    ) {
        let resolvedAppSettings = appSettings ?? AppSettings()
        let resolvedSnackbarQueue = snackbarQueue ?? SnackbarQueue()

        self.modelContainer = modelContainer
        self.appSettings = resolvedAppSettings
        self.appSettingsRepo = appSettingsRepo ?? UserDefaultsAppSettingsRepository()
        self.trackingService = trackingService ?? TrackingAuthorizationService()
        self.snackbarQueue = resolvedSnackbarQueue
        self.settingsRedirectCoordinator = settingsRedirectCoordinator ?? SettingsRedirectCoordinator()
        self.permissionStatusService = permissionStatusService ?? PermissionStatusService()
        self.thumbnailCache = thumbnailCache ?? PhotoLibraryThumbnailCache()
        self.hapticService = hapticService ?? HapticService()
        self.motionService = motionService ?? MotionService()

        let resolvedTrackingService = self.trackingService
        self.interstitialAdManager = interstitialAdManager
            ?? InterstitialAdManager(trackingService: resolvedTrackingService)
        self.rewardedAdManager = rewardedAdManager
            ?? RewardedAdManager(trackingService: resolvedTrackingService)
        self.nativeAdLoader = nativeAdLoader
            ?? NativeAdLoader(trackingService: resolvedTrackingService)
        self.appOpenAdManager = appOpenAdManager
            ?? AppOpenAdManager(trackingService: resolvedTrackingService)
        self.fullscreenAdCoordinator = fullscreenAdCoordinator ?? FullscreenAdCoordinator()

        let resolvedLocation = CoreLocationService()
        let resolvedPhotoLibraryExporter = PhotoLibraryExport()
        let resolvedPhotoLibrary = PhotoLibraryService()

        location = resolvedLocation
        photoLibraryExporter = resolvedPhotoLibraryExporter
        photoLibrary = resolvedPhotoLibrary
        photoLibrarySync = PhotoLibrarySyncService(
            container: modelContainer,
            photoLibrary: resolvedPhotoLibrary
        )

        let resolvedPairRepo = SwiftDataPhotoPairRepository(container: modelContainer)
        let resolvedAlbumRepo = SwiftDataAlbumRepository(container: modelContainer)
        pairRepo = resolvedPairRepo
        albumRepo = resolvedAlbumRepo

        let resolvedZipExporter = ZipExporterAdapter(
            photoLibrary: resolvedPhotoLibrary,
            pairRepo: resolvedPairRepo,
            appSettings: resolvedAppSettings
        )
        zipExporter = resolvedZipExporter

        createPair = CreatePairUseCase(
            pairRepo: resolvedPairRepo,
            photoLibrary: resolvedPhotoLibrary,
            location: resolvedLocation
        )
        captureAfter = CaptureAfterUseCase(
            pairRepo: resolvedPairRepo,
            photoLibrary: resolvedPhotoLibrary
        )
        deletePairs = DeletePairsUseCase(
            pairRepo: resolvedPairRepo,
            photoLibrary: resolvedPhotoLibrary
        )
        deleteCombinedExports = DeleteCombinedExportsUseCase(
            pairRepo: resolvedPairRepo,
            photoLibrary: resolvedPhotoLibrary
        )
        deletePairsKeepingCombined = DeletePairsKeepingCombinedUseCase(
            pairRepo: resolvedPairRepo,
            photoLibrary: resolvedPhotoLibrary
        )
        let resolvedExportPairs = ExportPairsUseCase(
            pairRepo: resolvedPairRepo,
            zipExporter: resolvedZipExporter
        )
        exportPairs = resolvedExportPairs
        toggleAlbumMembership = ToggleAlbumMembershipUseCase(
            albumRepo: resolvedAlbumRepo
        )
        immediateExport = ImmediateExportService(
            photoLibrary: resolvedPhotoLibrary,
            exportPairs: resolvedExportPairs,
            photoLibraryExporter: resolvedPhotoLibraryExporter,
            snackbarQueue: resolvedSnackbarQueue,
            appSettings: resolvedAppSettings,
            pairRepo: resolvedPairRepo
        )
    }

    func makeBeforeCameraViewModel(
        albumId: UUID?,
        refillPairId: UUID? = nil
    ) -> BeforeCameraViewModel {
        BeforeCameraViewModel(
            albumId: albumId,
            refillPairId: refillPairId,
            createPair: createPair,
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            appSettings: appSettings,
            hapticService: hapticService,
            session: makeCameraSession(),
            permissionProbe: makeCameraPermissionProbe()
        )
    }

    func makeAfterCameraViewModel(
        albumId: UUID?,
        initialPairId: UUID? = nil,
        sortOrder: HomeSortOrder = .newest
    ) -> AfterCameraViewModel {
        AfterCameraViewModel(
            albumId: albumId,
            initialPairId: initialPairId,
            sortOrder: sortOrder,
            captureAfter: captureAfter,
            pairRepo: pairRepo,
            photoLibrary: photoLibrary,
            appSettings: appSettings,
            hapticService: hapticService,
            session: makeCameraSession(),
            permissionProbe: makeCameraPermissionProbe()
        )
    }

    private func makeCameraSession() -> CameraSession {
        let probe = makeCameraPermissionProbe()
        let resolver: @Sendable () async -> CameraAuthorizationState = {
            await probe() ? .authorized : .denied
        }
        return CameraSession(permissionResolver: resolver)
    }

    private func makeCameraPermissionProbe() -> @Sendable () async -> Bool {
        let service = permissionStatusService
        return { await service.requestCameraAccessIfNeeded() }
    }

    func makePairPreviewViewModel(pair: PhotoPair) -> PairPreviewViewModel {
        PairPreviewViewModel(
            pair: pair,
            photoLibrary: photoLibrary,
            appSettings: appSettings
        )
    }

    func makeAlbumDetailViewModel(albumId: UUID) -> AlbumDetailViewModel {
        AlbumDetailViewModel(
            albumId: albumId,
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            deletePairs: deletePairs,
            toggleAlbumMembership: toggleAlbumMembership,
            photoLibrary: photoLibrary,
            immediateExport: immediateExport,
            appSettings: appSettings,
            thumbnailCache: thumbnailCache,
            interstitialAdManager: interstitialAdManager,
            fullscreenAdCoordinator: fullscreenAdCoordinator,
            deleteCombinedExports: deleteCombinedExports,
            deletePairsKeepingCombined: deletePairsKeepingCombined
        )
    }

    func makePairPickerViewModel(albumId: UUID) -> PairPickerViewModel {
        PairPickerViewModel(
            albumId: albumId,
            toggleAlbumMembership: toggleAlbumMembership,
            photoLibrary: photoLibrary
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            deletePairs: deletePairs,
            toggleAlbumMembership: toggleAlbumMembership,
            photoLibrary: photoLibrary,
            location: location,
            immediateExport: immediateExport,
            appSettings: appSettings,
            thumbnailCache: thumbnailCache,
            interstitialAdManager: interstitialAdManager,
            fullscreenAdCoordinator: fullscreenAdCoordinator,
            deleteCombinedExports: deleteCombinedExports,
            deletePairsKeepingCombined: deletePairsKeepingCombined
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        if let sharedSettingsViewModel { return sharedSettingsViewModel }
        let viewModel = SettingsViewModel(
            appSettings: appSettings,
            appSettingsRepo: appSettingsRepo,
            thumbnailCache: thumbnailCache,
            hapticService: hapticService
        )
        sharedSettingsViewModel = viewModel
        return viewModel
    }

    func makeWatermarkSettingsViewModel() -> WatermarkSettingsViewModel {
        WatermarkSettingsViewModel(appSettingsRepo: appSettingsRepo, appSettings: appSettings)
    }

    func makeCombineSettingsViewModel() -> CombineSettingsViewModel {
        CombineSettingsViewModel(appSettingsRepo: appSettingsRepo, appSettings: appSettings)
    }

    func makeExportSettingsViewModel(
        pairIds: [UUID],
        albumId: UUID?
    ) -> ExportSettingsViewModel {
        ExportSettingsViewModel(
            pairIds: pairIds,
            albumId: albumId,
            pairRepo: pairRepo,
            photoLibrary: photoLibrary,
            exportPairs: exportPairs,
            photoLibraryExporter: photoLibraryExporter,
            snackbarQueue: snackbarQueue,
            appSettings: appSettings,
            interstitialAdManager: interstitialAdManager,
            fullscreenAdCoordinator: fullscreenAdCoordinator
        )
    }
}
