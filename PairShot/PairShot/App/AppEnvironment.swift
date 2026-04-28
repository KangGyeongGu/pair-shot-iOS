import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppEnvironment {
    let modelContainer: ModelContainer

    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let couponRepo: CouponRepository

    let location: LocationFetching
    let exifNormalizer: ExifNormalizing
    let couponApiConfig: CouponApiConfig
    let couponApi: any CouponActivationApi
    let deviceHashProvider: any DeviceHashProviding
    let zipExporter: ZipExporting
    let photoLibraryExporter: any PhotoLibraryExporting
    let photoLibrary: PhotoLibraryService
    let photoLibrarySyncService: PhotoLibrarySyncService

    let createPair: CreatePairUseCase
    let captureAfter: CaptureAfterUseCase
    let deletePairs: DeletePairsUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase
    let exportPairs: ExportPairsUseCase
    let toggleAlbumMembership: ToggleAlbumMembershipUseCase
    let activateCoupon: ActivateCouponUseCase
    let checkAdFreeState: CheckAdFreeStateUseCase

    let appSettings: AppSettings
    let appSettingsRepo: AppSettingsRepository
    let adFreeStore: AdFreeStore
    let trackingService: TrackingAuthorizationService

    let interstitialAdManager: InterstitialAdManager
    let rewardedAdManager: RewardedAdManager
    let nativeAdLoader: NativeAdLoader
    let appOpenAdManager: AppOpenAdManager
    let fullscreenAdCoordinator: FullscreenAdCoordinator

    let snackbarQueue: SnackbarQueue
    let backgroundTaskGuard: BackgroundTaskGuard
    let compositorService: any CompositorService
    let immediateExport: ImmediateExportService
    let settingsRedirectCoordinator: SettingsRedirectCoordinator
    let permissionStatusService: PermissionStatusService
    let thumbnailCache: ThumbnailCache
    let hapticService: HapticService

    private var sharedSettingsViewModel: SettingsViewModel?

    // swiftlint:disable:next function_body_length
    init(
        modelContainer: ModelContainer,
        appSettings: AppSettings? = nil,
        appSettingsRepo: AppSettingsRepository? = nil,
        adFreeStore: AdFreeStore? = nil,
        trackingService: TrackingAuthorizationService? = nil,
        interstitialAdManager: InterstitialAdManager? = nil,
        rewardedAdManager: RewardedAdManager? = nil,
        nativeAdLoader: NativeAdLoader? = nil,
        appOpenAdManager: AppOpenAdManager? = nil,
        fullscreenAdCoordinator: FullscreenAdCoordinator? = nil,
        snackbarQueue: SnackbarQueue? = nil,
        backgroundTaskGuard: BackgroundTaskGuard? = nil,
        settingsRedirectCoordinator: SettingsRedirectCoordinator? = nil,
        permissionStatusService: PermissionStatusService? = nil,
        thumbnailCache: ThumbnailCache? = nil,
        hapticService: HapticService? = nil
    ) {
        let resolvedAppSettings = appSettings ?? AppSettings()
        let resolvedSnackbarQueue = snackbarQueue ?? SnackbarQueue()

        self.modelContainer = modelContainer
        self.appSettings = resolvedAppSettings
        self.appSettingsRepo = appSettingsRepo ?? UserDefaultsAppSettingsRepository()
        self.adFreeStore = adFreeStore ?? AdFreeStore(context: modelContainer.mainContext)
        self.trackingService = trackingService ?? TrackingAuthorizationService()
        self.snackbarQueue = resolvedSnackbarQueue
        self.backgroundTaskGuard = backgroundTaskGuard ?? BackgroundTaskGuard()
        self.settingsRedirectCoordinator = settingsRedirectCoordinator ?? SettingsRedirectCoordinator()
        self.permissionStatusService = permissionStatusService ?? PermissionStatusService()
        let resolvedThumbnailCache = thumbnailCache ?? ThumbnailCache()
        self.thumbnailCache = resolvedThumbnailCache
        self.hapticService = hapticService ?? HapticService()

        let ads = Self.makeAdManagers(
            interstitialAdManager: interstitialAdManager,
            rewardedAdManager: rewardedAdManager,
            nativeAdLoader: nativeAdLoader,
            appOpenAdManager: appOpenAdManager,
            fullscreenAdCoordinator: fullscreenAdCoordinator,
            trackingService: self.trackingService
        )
        self.interstitialAdManager = ads.interstitialAdManager
        self.rewardedAdManager = ads.rewardedAdManager
        self.nativeAdLoader = ads.nativeAdLoader
        self.appOpenAdManager = ads.appOpenAdManager
        self.fullscreenAdCoordinator = ads.fullscreenAdCoordinator

        let services = AppServiceBundle.make()
        let repositories = AppRepositoryBundle.make(
            container: modelContainer,
            couponApi: services.couponApi,
            deviceHashProvider: services.deviceHashProvider
        )
        let pipeline = Self.makeCorePipeline(
            services: services,
            repositories: repositories,
            appSettings: resolvedAppSettings,
            snackbarQueue: resolvedSnackbarQueue,
            modelContainer: modelContainer
        )

        location = services.location
        exifNormalizer = services.exifNormalizer
        couponApiConfig = services.couponApiConfig
        couponApi = services.couponApi
        deviceHashProvider = services.deviceHashProvider
        photoLibraryExporter = services.photoLibraryExporter
        photoLibrary = services.photoLibrary
        photoLibrarySyncService = PhotoLibrarySyncService(
            modelContainer: modelContainer,
            photoLibrary: services.photoLibrary,
            thumbnailCache: resolvedThumbnailCache
        )
        pairRepo = repositories.pairRepo
        albumRepo = repositories.albumRepo
        couponRepo = repositories.couponRepo
        compositorService = pipeline.compositor
        zipExporter = pipeline.zipExporter
        createPair = pipeline.useCases.createPair
        captureAfter = pipeline.useCases.captureAfter
        deletePairs = pipeline.useCases.deletePairs
        deleteCombinedExports = pipeline.useCases.deleteCombinedExports
        exportPairs = pipeline.useCases.exportPairs
        toggleAlbumMembership = pipeline.useCases.toggleAlbumMembership
        activateCoupon = pipeline.useCases.activateCoupon
        checkAdFreeState = pipeline.useCases.checkAdFreeState
        immediateExport = pipeline.immediateExport
    }

    private static func makeCorePipeline(
        services: AppServiceBundle,
        repositories: AppRepositoryBundle,
        appSettings: AppSettings,
        snackbarQueue: SnackbarQueue,
        modelContainer: ModelContainer
    ) -> AppCorePipelineBundle {
        let compositor = DefaultCompositorService(photoLibrary: services.photoLibrary)
        let zipExporter = ZipExporterAdapter(
            photoLibrary: services.photoLibrary,
            pairRepo: repositories.pairRepo,
            compositor: compositor,
            appSettings: appSettings
        )
        let useCases = AppUseCaseBundle.make(
            services: services,
            repositories: repositories,
            zipExporter: zipExporter
        )
        let immediateExport = ImmediateExportService(
            photoLibrary: services.photoLibrary,
            exportPairs: useCases.exportPairs,
            photoLibraryExporter: services.photoLibraryExporter,
            snackbarQueue: snackbarQueue,
            compositor: compositor,
            appSettings: appSettings,
            modelContainer: modelContainer
        )
        return AppCorePipelineBundle(
            compositor: compositor,
            zipExporter: zipExporter,
            useCases: useCases,
            immediateExport: immediateExport
        )
    }

    private static func makeAdManagers(
        interstitialAdManager: InterstitialAdManager?,
        rewardedAdManager: RewardedAdManager?,
        nativeAdLoader: NativeAdLoader?,
        appOpenAdManager: AppOpenAdManager?,
        fullscreenAdCoordinator: FullscreenAdCoordinator?,
        trackingService: TrackingAuthorizationService
    ) -> AppAdManagerBundle {
        AppAdManagerBundle(
            interstitialAdManager: interstitialAdManager
                ?? InterstitialAdManager(trackingService: trackingService),
            rewardedAdManager: rewardedAdManager
                ?? RewardedAdManager(trackingService: trackingService),
            nativeAdLoader: nativeAdLoader
                ?? NativeAdLoader(trackingService: trackingService),
            appOpenAdManager: appOpenAdManager
                ?? AppOpenAdManager(trackingService: trackingService),
            fullscreenAdCoordinator: fullscreenAdCoordinator ?? FullscreenAdCoordinator()
        )
    }

    func makeBeforeCameraViewModel(
        albumId: UUID?,
        refillPairId: UUID? = nil
    ) -> BeforeCameraViewModel {
        let bundle = makeCameraSessionBundle()
        return BeforeCameraViewModel(
            albumId: albumId,
            refillPairId: refillPairId,
            createPair: createPair,
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            appSettings: appSettings,
            hapticService: hapticService,
            session: bundle.session,
            permissionProbe: bundle.probe
        )
    }

    func makeAfterCameraViewModel(
        albumId: UUID?,
        initialPairId: UUID? = nil,
        sortOrder: HomeSortOrder = .newest
    ) -> AfterCameraViewModel {
        let bundle = makeCameraSessionBundle()
        return AfterCameraViewModel(
            albumId: albumId,
            initialPairId: initialPairId,
            sortOrder: sortOrder,
            captureAfter: captureAfter,
            pairRepo: pairRepo,
            photoLibrary: photoLibrary,
            appSettings: appSettings,
            hapticService: hapticService,
            session: bundle.session,
            permissionProbe: bundle.probe
        )
    }

    private func makeCameraSessionBundle() -> CameraSessionBundle {
        let service = permissionStatusService
        let probe: @Sendable () async -> Bool = {
            await service.requestCameraAccessIfNeeded()
        }
        let resolver: @Sendable () async -> CameraAuthorizationState = {
            await probe() ? .authorized : .denied
        }
        return CameraSessionBundle(
            session: CameraSession(permissionResolver: resolver),
            probe: probe
        )
    }

    func makePairPreviewViewModel(pair: PhotoPair) -> PairPreviewViewModel {
        PairPreviewViewModel(
            pair: pair,
            compositor: compositorService,
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
            adFreeStore: adFreeStore,
            fullscreenAdCoordinator: fullscreenAdCoordinator,
            deleteCombinedExports: deleteCombinedExports
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
            adFreeStore: adFreeStore,
            fullscreenAdCoordinator: fullscreenAdCoordinator,
            deleteCombinedExports: deleteCombinedExports
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
        WatermarkSettingsViewModel(appSettingsRepo: appSettingsRepo)
    }

    func makeCombineSettingsViewModel() -> CombineSettingsViewModel {
        CombineSettingsViewModel(appSettingsRepo: appSettingsRepo)
    }

    func makeAdFreeStatusViewModel() -> AdFreeStatusViewModel {
        AdFreeStatusViewModel(store: adFreeStore)
    }

    func makeCouponRegistrationViewModel() -> CouponRegistrationViewModel {
        CouponRegistrationViewModel(
            activate: activateCoupon,
            couponRepo: couponRepo,
            store: adFreeStore
        )
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
            compositor: compositorService,
            appSettings: appSettings,
            interstitialAdManager: interstitialAdManager,
            adFreeStore: adFreeStore,
            fullscreenAdCoordinator: fullscreenAdCoordinator,
            modelContainer: modelContainer
        )
    }
}

@MainActor
struct AppAdManagerBundle {
    let interstitialAdManager: InterstitialAdManager
    let rewardedAdManager: RewardedAdManager
    let nativeAdLoader: NativeAdLoader
    let appOpenAdManager: AppOpenAdManager
    let fullscreenAdCoordinator: FullscreenAdCoordinator
}

@MainActor
struct CameraSessionBundle {
    let session: CameraSession
    let probe: @Sendable () async -> Bool
}

@MainActor
struct AppCorePipelineBundle {
    let compositor: any CompositorService
    let zipExporter: ZipExporting
    let useCases: AppUseCaseBundle
    let immediateExport: ImmediateExportService
}

@MainActor
struct AppServiceBundle {
    let location: LocationFetching
    let exifNormalizer: ExifNormalizing
    let couponApiConfig: CouponApiConfig
    let couponApi: any CouponActivationApi
    let deviceHashProvider: any DeviceHashProviding
    let photoLibraryExporter: any PhotoLibraryExporting
    let photoLibrary: PhotoLibraryService

    static func make() -> Self {
        let apiConfig = CouponApiConfig.resolve()
        let api = URLSessionCouponActivationApi(config: apiConfig)
        let hashProvider = DeviceHashProvider(salt: apiConfig.deviceHashSalt)
        return Self(
            location: LocationFetcherAdapter(provider: CoreLocationService()),
            exifNormalizer: ExifNormalizerAdapter(),
            couponApiConfig: apiConfig,
            couponApi: api,
            deviceHashProvider: hashProvider,
            photoLibraryExporter: PhotoLibraryExport(),
            photoLibrary: PhotoLibraryService()
        )
    }
}

@MainActor
struct AppRepositoryBundle {
    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let couponRepo: CouponRepository

    static func make(
        container: ModelContainer,
        couponApi: any CouponActivationApi,
        deviceHashProvider: any DeviceHashProviding
    ) -> Self {
        Self(
            pairRepo: SwiftDataPhotoPairRepository(container: container),
            albumRepo: SwiftDataAlbumRepository(container: container),
            couponRepo: SwiftDataCouponRepository(
                container: container,
                api: couponApi,
                deviceHashProvider: deviceHashProvider
            )
        )
    }
}

@MainActor
struct AppUseCaseBundle {
    let createPair: CreatePairUseCase
    let captureAfter: CaptureAfterUseCase
    let deletePairs: DeletePairsUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase
    let exportPairs: ExportPairsUseCase
    let toggleAlbumMembership: ToggleAlbumMembershipUseCase
    let activateCoupon: ActivateCouponUseCase
    let checkAdFreeState: CheckAdFreeStateUseCase

    static func make(
        services: AppServiceBundle,
        repositories: AppRepositoryBundle,
        zipExporter: ZipExporting
    ) -> Self {
        Self(
            createPair: CreatePairUseCase(
                pairRepo: repositories.pairRepo,
                photoLibrary: services.photoLibrary,
                location: services.location,
                exifNormalizer: services.exifNormalizer
            ),
            captureAfter: CaptureAfterUseCase(
                pairRepo: repositories.pairRepo,
                photoLibrary: services.photoLibrary,
                exifNormalizer: services.exifNormalizer
            ),
            deletePairs: DeletePairsUseCase(
                pairRepo: repositories.pairRepo,
                photoLibrary: services.photoLibrary
            ),
            deleteCombinedExports: DeleteCombinedExportsUseCase(
                pairRepo: repositories.pairRepo,
                photoLibrary: services.photoLibrary
            ),
            exportPairs: ExportPairsUseCase(
                pairRepo: repositories.pairRepo,
                zipExporter: zipExporter
            ),
            toggleAlbumMembership: ToggleAlbumMembershipUseCase(
                albumRepo: repositories.albumRepo
            ),
            activateCoupon: ActivateCouponUseCase(
                couponRepo: repositories.couponRepo
            ),
            checkAdFreeState: CheckAdFreeStateUseCase(
                couponRepo: repositories.couponRepo
            )
        )
    }
}
