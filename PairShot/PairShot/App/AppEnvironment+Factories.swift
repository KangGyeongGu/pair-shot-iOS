import Foundation
import SwiftData

struct AppEnvironmentFoundationOverrides {
    let appSettings: AppSettings?
    let snackbarQueue: SnackbarQueue?
    let appSettingsRepo: AppSettingsRepository?
    let adFreeStore: AdFreeStore?
    let trackingService: TrackingAuthorizationService?
    let settingsRedirectCoordinator: SettingsRedirectCoordinator?
    let permissionStatusService: PermissionStatusService?
    let thumbnailCache: PhotoLibraryThumbnailCache?
    let hapticService: HapticService?
    let motionService: MotionService?
}

struct AppEnvironmentFoundation {
    let appSettings: AppSettings
    let snackbarQueue: SnackbarQueue
    let appSettingsRepo: AppSettingsRepository
    let adFreeStore: AdFreeStore
    let trackingService: TrackingAuthorizationService
    let settingsRedirectCoordinator: SettingsRedirectCoordinator
    let permissionStatusService: PermissionStatusService
    let thumbnailCache: PhotoLibraryThumbnailCache
    let hapticService: HapticService
    let motionService: MotionService
    let apiConfig: CouponApiConfig
    let deviceHashProvider: DeviceHashProvider
    let adFreeStatusFetcher: AdFreeStatusFetcher
}

struct AdServicesOverrides {
    let interstitial: InterstitialAdManager?
    let rewarded: RewardedAdManager?
    let nativeAd: NativeAdLoader?
    let appOpen: AppOpenAdManager?
    let fullscreen: FullscreenAdCoordinator?
    let consent: ConsentManager?
}

struct AdServicesBundle {
    let interstitial: InterstitialAdManager
    let rewarded: RewardedAdManager
    let nativeAd: NativeAdLoader
    let appOpen: AppOpenAdManager
    let fullscreen: FullscreenAdCoordinator
    let consent: ConsentManager
}

struct DataServicesBundle {
    let location: CoreLocationService
    let photoLibraryExporter: PhotoLibraryExport
    let photoLibrary: PhotoLibraryService
    let photoLibrarySync: PhotoLibrarySyncService
    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let zipExporter: ZipExporterAdapter
}

struct UseCasesDependencies {
    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let photoLibrary: PhotoLibraryService
    let photoLibraryExporter: PhotoLibraryExport
    let location: CoreLocationService
    let zipExporter: ZipExporterAdapter
    let snackbarQueue: SnackbarQueue
    let appSettings: AppSettings
}

struct UseCasesBundle {
    let createPair: CreatePairUseCase
    let captureAfter: CaptureAfterUseCase
    let recaptureAfter: RecaptureAfterUseCase
    let deletePairs: DeletePairsUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase
    let deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase
    let exportPairs: ExportPairsUseCase
    let toggleAlbumMembership: ToggleAlbumMembershipUseCase
    let immediateExport: ImmediateExportService
}

extension AppEnvironment {
    static func makeFoundation(
        overrides: AppEnvironmentFoundationOverrides
    ) -> AppEnvironmentFoundation {
        let apiConfig = CouponApiConfig.resolve()
        let hashProvider = DeviceHashProvider()
        let statusFetcher = AdFreeStatusFetcher(config: apiConfig)
        return AppEnvironmentFoundation(
            appSettings: overrides.appSettings ?? AppSettings(),
            snackbarQueue: overrides.snackbarQueue ?? SnackbarQueue(),
            appSettingsRepo: overrides.appSettingsRepo ?? UserDefaultsAppSettingsRepository(),
            adFreeStore: overrides.adFreeStore ?? AdFreeStore(fetcher: statusFetcher, deviceHashProvider: hashProvider),
            trackingService: overrides.trackingService ?? TrackingAuthorizationService(),
            settingsRedirectCoordinator: overrides.settingsRedirectCoordinator ?? SettingsRedirectCoordinator(),
            permissionStatusService: overrides.permissionStatusService ?? PermissionStatusService(),
            thumbnailCache: overrides.thumbnailCache ?? PhotoLibraryThumbnailCache(),
            hapticService: overrides.hapticService ?? HapticService(),
            motionService: overrides.motionService ?? MotionService(),
            apiConfig: apiConfig,
            deviceHashProvider: hashProvider,
            adFreeStatusFetcher: statusFetcher
        )
    }

    static func makeDataServices(
        modelContainer: ModelContainer,
        appSettings: AppSettings
    ) -> DataServicesBundle {
        let location = CoreLocationService()
        let photoLibraryExporter = PhotoLibraryExport()
        let photoLibrary = PhotoLibraryService()
        let pairRepo = SwiftDataPhotoPairRepository(container: modelContainer)
        let albumRepo = SwiftDataAlbumRepository(container: modelContainer)
        return DataServicesBundle(
            location: location,
            photoLibraryExporter: photoLibraryExporter,
            photoLibrary: photoLibrary,
            photoLibrarySync: PhotoLibrarySyncService(container: modelContainer, photoLibrary: photoLibrary),
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            zipExporter: ZipExporterAdapter(
                photoLibrary: photoLibrary,
                pairRepo: pairRepo,
                appSettings: appSettings
            )
        )
    }

    static func makeAdServices(
        trackingService: TrackingAuthorizationService,
        overrides: AdServicesOverrides
    ) -> AdServicesBundle {
        AdServicesBundle(
            interstitial: overrides.interstitial ?? InterstitialAdManager(trackingService: trackingService),
            rewarded: overrides.rewarded ?? RewardedAdManager(trackingService: trackingService),
            nativeAd: overrides.nativeAd ?? NativeAdLoader(trackingService: trackingService),
            appOpen: overrides.appOpen ?? AppOpenAdManager(trackingService: trackingService),
            fullscreen: overrides.fullscreen ?? FullscreenAdCoordinator(),
            consent: overrides.consent ?? ConsentManager()
        )
    }

    static func makeUseCases(
        dependencies: UseCasesDependencies
    ) -> UseCasesBundle {
        let pairRepo = dependencies.pairRepo
        let photoLibrary = dependencies.photoLibrary
        let captureAfter = CaptureAfterUseCase(pairRepo: pairRepo, photoLibrary: photoLibrary)
        let exportPairs = ExportPairsUseCase(pairRepo: pairRepo, zipExporter: dependencies.zipExporter)
        let recaptureAfter = RecaptureAfterUseCase(
            pairRepo: pairRepo,
            photoLibrary: photoLibrary,
            captureAfter: captureAfter
        )
        let deletePairsKeepingCombined = DeletePairsKeepingCombinedUseCase(
            pairRepo: pairRepo,
            photoLibrary: photoLibrary
        )
        return UseCasesBundle(
            createPair: CreatePairUseCase(
                pairRepo: pairRepo,
                photoLibrary: photoLibrary,
                location: dependencies.location
            ),
            captureAfter: captureAfter,
            recaptureAfter: recaptureAfter,
            deletePairs: DeletePairsUseCase(pairRepo: pairRepo, photoLibrary: photoLibrary),
            deleteCombinedExports: DeleteCombinedExportsUseCase(pairRepo: pairRepo, photoLibrary: photoLibrary),
            deletePairsKeepingCombined: deletePairsKeepingCombined,
            exportPairs: exportPairs,
            toggleAlbumMembership: ToggleAlbumMembershipUseCase(albumRepo: dependencies.albumRepo),
            immediateExport: ImmediateExportService(
                photoLibrary: photoLibrary,
                exportPairs: exportPairs,
                photoLibraryExporter: dependencies.photoLibraryExporter,
                snackbarQueue: dependencies.snackbarQueue,
                appSettings: dependencies.appSettings,
                pairRepo: pairRepo
            )
        )
    }
}
