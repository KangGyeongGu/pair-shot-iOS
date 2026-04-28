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

    let storage: PhotoStoring
    let location: LocationFetching
    let fileNameBuilder: FileNameBuilding
    let exifNormalizer: ExifNormalizing
    let couponApiConfig: CouponApiConfig
    let couponApi: any CouponActivationApi
    let deviceHashProvider: any DeviceHashProviding
    let zipExporter: ZipExporting
    let photoLibraryExporter: any PhotoLibraryExporting
    let photoStorageService: PhotoStorageService

    let createPair: CreatePairUseCase
    let captureAfter: CaptureAfterUseCase
    let deletePairs: DeletePairsUseCase
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
        settingsRedirectCoordinator: SettingsRedirectCoordinator? = nil
    ) {
        self.modelContainer = modelContainer
        self.appSettings = appSettings ?? AppSettings()
        self.appSettingsRepo = appSettingsRepo ?? UserDefaultsAppSettingsRepository()
        self.adFreeStore = adFreeStore ?? AdFreeStore(context: modelContainer.mainContext)
        self.trackingService = trackingService ?? TrackingAuthorizationService()
        self.interstitialAdManager = interstitialAdManager ?? InterstitialAdManager()
        self.rewardedAdManager = rewardedAdManager ?? RewardedAdManager()
        self.nativeAdLoader = nativeAdLoader ?? NativeAdLoader()
        self.appOpenAdManager = appOpenAdManager ?? AppOpenAdManager()
        self.fullscreenAdCoordinator = fullscreenAdCoordinator ?? FullscreenAdCoordinator()
        let resolvedSnackbarQueue = snackbarQueue ?? SnackbarQueue()
        let resolvedBackgroundTaskGuard = backgroundTaskGuard ?? BackgroundTaskGuard()
        self.snackbarQueue = resolvedSnackbarQueue
        self.backgroundTaskGuard = resolvedBackgroundTaskGuard
        self.settingsRedirectCoordinator = settingsRedirectCoordinator ?? SettingsRedirectCoordinator()

        let services = AppServiceBundle.make()
        storage = services.storage
        photoStorageService = services.photoStorageService
        location = services.location
        fileNameBuilder = services.fileNameBuilder
        exifNormalizer = services.exifNormalizer
        couponApiConfig = services.couponApiConfig
        couponApi = services.couponApi
        deviceHashProvider = services.deviceHashProvider
        photoLibraryExporter = services.photoLibraryExporter

        let repositories = AppRepositoryBundle.make(
            container: modelContainer,
            couponApi: services.couponApi,
            deviceHashProvider: services.deviceHashProvider
        )
        pairRepo = repositories.pairRepo
        albumRepo = repositories.albumRepo
        couponRepo = repositories.couponRepo

        zipExporter = ZipExporterAdapter(
            storage: services.photoStorageService,
            pairRepo: repositories.pairRepo
        )

        let resolvedCompositor = DefaultCompositorService(
            storage: services.photoStorageService,
            modelContainer: modelContainer
        )
        compositorService = resolvedCompositor

        let useCases = AppUseCaseBundle.make(
            services: services,
            repositories: repositories,
            zipExporter: zipExporter
        )
        createPair = useCases.createPair
        captureAfter = useCases.captureAfter
        deletePairs = useCases.deletePairs
        exportPairs = useCases.exportPairs
        toggleAlbumMembership = useCases.toggleAlbumMembership
        activateCoupon = useCases.activateCoupon
        checkAdFreeState = useCases.checkAdFreeState

        immediateExport = ImmediateExportService(
            storage: services.photoStorageService,
            exportPairs: useCases.exportPairs,
            photoLibrary: services.photoLibraryExporter,
            snackbarQueue: resolvedSnackbarQueue,
            compositor: resolvedCompositor,
            appSettings: self.appSettings
        )
    }

    func makeBeforeCameraViewModel(albumId: UUID?) -> BeforeCameraViewModel {
        BeforeCameraViewModel(
            albumId: albumId,
            createPair: createPair,
            pairRepo: pairRepo,
            storage: storage,
            albumRepo: albumRepo,
            appSettings: appSettings
        )
    }

    func makeAfterCameraViewModel(
        albumId: UUID?,
        initialPairId: UUID? = nil,
        retakeMode: Bool = false,
        sortOrder: HomeSortOrder = .newest
    ) -> AfterCameraViewModel {
        AfterCameraViewModel(
            albumId: albumId,
            initialPairId: initialPairId,
            retakeMode: retakeMode,
            sortOrder: sortOrder,
            captureAfter: captureAfter,
            pairRepo: pairRepo,
            storage: storage,
            appSettings: appSettings
        )
    }

    func makePairPreviewViewModel(pair: PhotoPair) -> PairPreviewViewModel {
        PairPreviewViewModel(
            pair: pair,
            storage: photoStorageService,
            deletePairs: deletePairs
        )
    }

    func makeAlbumDetailViewModel(albumId: UUID) -> AlbumDetailViewModel {
        AlbumDetailViewModel(
            albumId: albumId,
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            deletePairs: deletePairs,
            toggleAlbumMembership: toggleAlbumMembership,
            storage: photoStorageService,
            immediateExport: immediateExport,
            appSettings: appSettings,
            interstitialAdManager: interstitialAdManager,
            adFreeStore: adFreeStore,
            fullscreenAdCoordinator: fullscreenAdCoordinator
        )
    }

    func makePairPickerViewModel(albumId: UUID) -> PairPickerViewModel {
        PairPickerViewModel(
            albumId: albumId,
            toggleAlbumMembership: toggleAlbumMembership,
            storage: photoStorageService
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            deletePairs: deletePairs,
            toggleAlbumMembership: toggleAlbumMembership,
            storage: photoStorageService,
            location: location,
            immediateExport: immediateExport,
            appSettings: appSettings,
            interstitialAdManager: interstitialAdManager,
            adFreeStore: adFreeStore,
            fullscreenAdCoordinator: fullscreenAdCoordinator
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            appSettings: appSettings,
            appSettingsRepo: appSettingsRepo,
            storage: photoStorageService
        )
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
            storage: photoStorageService,
            exportPairs: exportPairs,
            photoLibrary: photoLibraryExporter,
            snackbarQueue: snackbarQueue,
            appSettings: appSettings,
            interstitialAdManager: interstitialAdManager,
            adFreeStore: adFreeStore,
            fullscreenAdCoordinator: fullscreenAdCoordinator
        )
    }

    deinit {}
}

@MainActor
struct AppServiceBundle {
    let storage: PhotoStoring
    let photoStorageService: PhotoStorageService
    let location: LocationFetching
    let fileNameBuilder: FileNameBuilding
    let exifNormalizer: ExifNormalizing
    let couponApiConfig: CouponApiConfig
    let couponApi: any CouponActivationApi
    let deviceHashProvider: any DeviceHashProviding
    let photoLibraryExporter: any PhotoLibraryExporting

    static func make() -> Self {
        let storage = PhotoStorageService()
        let apiConfig = CouponApiConfig.resolve()
        let api = URLSessionCouponActivationApi(config: apiConfig)
        let hashProvider = DeviceHashProvider(salt: apiConfig.deviceHashSalt)
        return Self(
            storage: storage,
            photoStorageService: storage,
            location: LocationFetcherAdapter(provider: CoreLocationService()),
            fileNameBuilder: FileNameBuilderAdapter(),
            exifNormalizer: ExifNormalizerAdapter(),
            couponApiConfig: apiConfig,
            couponApi: api,
            deviceHashProvider: hashProvider,
            photoLibraryExporter: PhotoLibraryExport()
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
                storage: services.storage,
                location: services.location,
                fileNameBuilder: services.fileNameBuilder,
                exifNormalizer: services.exifNormalizer
            ),
            captureAfter: CaptureAfterUseCase(
                pairRepo: repositories.pairRepo,
                storage: services.storage,
                fileNameBuilder: services.fileNameBuilder,
                exifNormalizer: services.exifNormalizer
            ),
            deletePairs: DeletePairsUseCase(
                pairRepo: repositories.pairRepo,
                storage: services.storage
            ),
            exportPairs: ExportPairsUseCase(
                pairRepo: repositories.pairRepo,
                storage: services.storage,
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
