import Foundation
import SwiftData

struct AppEnvironmentFoundationOverrides {
    let appSettings: AppSettings?
    let snackbarQueue: SnackbarQueue?
    let appSettingsRepo: AppSettingsRepository?
    let adFreeStore: AdFreeStore?
    let trackingService: TrackingAuthorizationService?
    let settingsRedirectCoordinator: SettingsRedirectCoordinator?
    let exportCompletionCoordinator: ExportCompletionCoordinator?
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
    let exportCompletionCoordinator: ExportCompletionCoordinator
    let permissionStatusService: PermissionStatusService
    let thumbnailCache: PhotoLibraryThumbnailCache
    let hapticService: HapticService
    let motionService: MotionService
    let apiConfig: CouponApiConfig
    let deviceHashProvider: DeviceHashProvider
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
    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let zipExporter: ZipExporterAdapter
}

struct UseCasesDependencies {
    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService
    let photoLibraryExporter: PhotoLibraryExport
    let location: CoreLocationService
    let zipExporter: ZipExporterAdapter
    let snackbarQueue: SnackbarQueue
    let appSettings: AppSettings
    let entitlement: Entitlement?
}

struct UseCasesBundle {
    let createPair: CreatePairUseCase
    let captureAfter: CaptureAfterUseCase
    let recaptureAfter: RecaptureAfterUseCase
    let deletePairs: DeletePairsUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase
    let deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase
    let exportPairs: ExportPairsUseCase
    let immediateExport: ImmediateExportService
}

struct SubscriptionServicesOverrides {
    let productsService: ProductsService?
    let subscriptionStore: SubscriptionStore?
    let transactionListener: TransactionListener?
}

struct SubscriptionServicesBundle {
    let productsService: ProductsService
    let subscriptionStore: SubscriptionStore
    let transactionListener: TransactionListener
}

struct AppEnvironmentInitInput {
    let modelContainer: ModelContainer
    let foundationOverrides: AppEnvironmentFoundationOverrides
    let adServicesOverrides: AdServicesOverrides
    let subscriptionOverrides: SubscriptionServicesOverrides
}

struct AppEnvironmentBundles {
    let foundation: AppEnvironmentFoundation
    let adServices: AdServicesBundle
    let dataServices: DataServicesBundle
    let useCases: UseCasesBundle
    let subscription: SubscriptionServicesBundle
    let entitlement: Entitlement
}

extension AppEnvironment {
    static func makeAllBundles(input: AppEnvironmentInitInput) -> AppEnvironmentBundles {
        let foundation = makeFoundation(overrides: input.foundationOverrides)
        let adServices = makeAdServices(
            trackingService: foundation.trackingService,
            overrides: input.adServicesOverrides
        )
        let dataServices = makeDataServices(
            modelContainer: input.modelContainer,
            appSettings: foundation.appSettings
        )
        let subscription = makeSubscriptionServices(overrides: input.subscriptionOverrides)
        let entitlement = Entitlement(
            subscriptionStore: subscription.subscriptionStore,
            adFreeStore: foundation.adFreeStore
        )
        let useCases = makeUseCases(
            dependencies: UseCasesDependencies(
                pairRepo: dataServices.pairRepo,
                photoLibrary: dataServices.photoLibrary,
                photoLibraryExporter: dataServices.photoLibraryExporter,
                location: dataServices.location,
                zipExporter: dataServices.zipExporter,
                snackbarQueue: foundation.snackbarQueue,
                appSettings: foundation.appSettings,
                entitlement: entitlement
            )
        )
        return AppEnvironmentBundles(
            foundation: foundation,
            adServices: adServices,
            dataServices: dataServices,
            useCases: useCases,
            subscription: subscription,
            entitlement: entitlement
        )
    }

    static func makeFoundation(
        overrides: AppEnvironmentFoundationOverrides
    ) -> AppEnvironmentFoundation {
        let apiConfig = CouponApiConfig.resolve()
        let hashProvider = DeviceHashProvider()
        let statusFetcher = AdFreeStatusFetcher(config: apiConfig)
        let hapticService = overrides.hapticService ?? HapticService()
        return AppEnvironmentFoundation(
            appSettings: overrides.appSettings ?? AppSettings(),
            snackbarQueue: overrides.snackbarQueue ?? SnackbarQueue(hapticService: hapticService),
            appSettingsRepo: overrides.appSettingsRepo ?? UserDefaultsAppSettingsRepository(),
            adFreeStore: overrides.adFreeStore ?? AdFreeStore(fetcher: statusFetcher, deviceHashProvider: hashProvider),
            trackingService: overrides.trackingService ?? TrackingAuthorizationService(),
            settingsRedirectCoordinator: overrides.settingsRedirectCoordinator ?? SettingsRedirectCoordinator(),
            exportCompletionCoordinator: overrides.exportCompletionCoordinator ?? ExportCompletionCoordinator(),
            permissionStatusService: overrides.permissionStatusService ?? PermissionStatusService(),
            thumbnailCache: overrides.thumbnailCache ?? PhotoLibraryThumbnailCache(),
            hapticService: hapticService,
            motionService: overrides.motionService ?? MotionService(),
            apiConfig: apiConfig,
            deviceHashProvider: hashProvider
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

    static func makeSubscriptionServices(
        overrides: SubscriptionServicesOverrides
    ) -> SubscriptionServicesBundle {
        let scheduler = RenewalReminderScheduler()
        return SubscriptionServicesBundle(
            productsService: overrides.productsService ?? ProductsService(),
            subscriptionStore: overrides.subscriptionStore
                ?? SubscriptionStore(renewalReminderScheduler: scheduler),
            transactionListener: overrides.transactionListener ?? TransactionListener()
        )
    }

    static func makeUseCases(
        dependencies: UseCasesDependencies
    ) -> UseCasesBundle {
        let pairRepo = dependencies.pairRepo
        let photoLibrary = dependencies.photoLibrary
        let captureAfter = CaptureAfterUseCase(pairRepo: pairRepo, photoLibrary: photoLibrary)
        let exportPairs = ExportPairsUseCase(zipExporter: dependencies.zipExporter)
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
            immediateExport: ImmediateExportService(
                photoLibrary: photoLibrary,
                exportPairs: exportPairs,
                photoLibraryExporter: dependencies.photoLibraryExporter,
                snackbarQueue: dependencies.snackbarQueue,
                appSettings: dependencies.appSettings,
                pairRepo: pairRepo,
                entitlement: dependencies.entitlement
            )
        )
    }
}
