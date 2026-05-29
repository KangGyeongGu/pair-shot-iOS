import Foundation
import SwiftData

struct AppEnvironmentFoundationOverrides {
    let appSettings: AppSettings?
    let snackbarQueue: SnackbarQueue?
    let appSettingsRepo: AppSettingsRepository?
    let promotionStore: PromotionStore?
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
    let promotionStore: PromotionStore
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
    let tutorialPhotoStore: TutorialPhotoStore
    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let zipExporter: ZipExporterAdapter
}

struct UseCasesDependencies {
    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService
    let tutorialPhotoStore: TutorialPhotoStore
    let photoLibraryExporter: PhotoLibraryExport
    let location: CoreLocationService
    let zipExporter: ZipExporterAdapter
    let snackbarQueue: SnackbarQueue
    let appSettings: AppSettings
    let membership: Membership?
}

struct UseCasesBundle {
    let createPair: CreatePairUseCase
    let captureAfter: CaptureAfterUseCase
    let deleteAfterPhoto: DeleteAfterPhotoUseCase
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
    let tutorialCoordinator: TutorialCoordinator
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
    let membership: Membership
}

extension AppEnvironment {
    static func makeAllBundles(input: AppEnvironmentInitInput) -> AppEnvironmentBundles {
        let tutorialPhotoStore = TutorialPhotoStore()
        let foundation = makeFoundation(
            overrides: input.foundationOverrides,
            tutorialPhotoStore: tutorialPhotoStore,
            tutorialCoordinator: input.tutorialCoordinator,
        )
        let adServices = makeAdServices(
            trackingService: foundation.trackingService,
            tutorialCoordinator: input.tutorialCoordinator,
            overrides: input.adServicesOverrides,
        )
        let dataServices = makeDataServices(
            modelContainer: input.modelContainer,
            appSettings: foundation.appSettings,
            tutorialPhotoStore: tutorialPhotoStore,
        )
        let subscription = makeSubscriptionServices(overrides: input.subscriptionOverrides)
        let membership = Membership(
            subscriptionStore: subscription.subscriptionStore,
            promotionStore: foundation.promotionStore,
        )
        let useCases = makeUseCases(
            dependencies: UseCasesDependencies(
                pairRepo: dataServices.pairRepo,
                photoLibrary: dataServices.photoLibrary,
                tutorialPhotoStore: dataServices.tutorialPhotoStore,
                photoLibraryExporter: dataServices.photoLibraryExporter,
                location: dataServices.location,
                zipExporter: dataServices.zipExporter,
                snackbarQueue: foundation.snackbarQueue,
                appSettings: foundation.appSettings,
                membership: membership,
            ),
        )
        return AppEnvironmentBundles(
            foundation: foundation,
            adServices: adServices,
            dataServices: dataServices,
            useCases: useCases,
            subscription: subscription,
            membership: membership,
        )
    }

    static func makeFoundation(
        overrides: AppEnvironmentFoundationOverrides,
        tutorialPhotoStore: TutorialPhotoStore,
        tutorialCoordinator: TutorialCoordinator,
    ) -> AppEnvironmentFoundation {
        let apiConfig = CouponApiConfig.resolve()
        let hashProvider = DeviceHashProvider()
        let promotionFetcher = PromotionFetcher(config: apiConfig)
        let hapticService = overrides.hapticService ?? HapticService()
        return AppEnvironmentFoundation(
            appSettings: overrides.appSettings ?? AppSettings(),
            snackbarQueue: overrides.snackbarQueue ?? SnackbarQueue(
                hapticService: hapticService,
                tutorialCoordinator: tutorialCoordinator,
            ),
            appSettingsRepo: overrides.appSettingsRepo ?? UserDefaultsAppSettingsRepository(),
            promotionStore: overrides.promotionStore
                ?? PromotionStore(fetcher: promotionFetcher, deviceHashProvider: hashProvider),
            trackingService: overrides.trackingService ?? TrackingAuthorizationService(),
            settingsRedirectCoordinator: overrides.settingsRedirectCoordinator ?? SettingsRedirectCoordinator(),
            exportCompletionCoordinator: overrides.exportCompletionCoordinator ?? ExportCompletionCoordinator(),
            permissionStatusService: overrides.permissionStatusService ?? PermissionStatusService(),
            thumbnailCache: overrides.thumbnailCache
                ?? PhotoLibraryThumbnailCache(tutorialPhotoStore: tutorialPhotoStore),
            hapticService: hapticService,
            motionService: overrides.motionService ?? MotionService(),
            apiConfig: apiConfig,
            deviceHashProvider: hashProvider,
        )
    }

    static func makeDataServices(
        modelContainer: ModelContainer,
        appSettings: AppSettings,
        tutorialPhotoStore: TutorialPhotoStore,
    ) -> DataServicesBundle {
        let location = CoreLocationService()
        let photoLibraryExporter = PhotoLibraryExport()
        let photoLibrary = PhotoLibraryService(tutorialPhotoStore: tutorialPhotoStore)
        let pairRepo = SwiftDataPhotoPairRepository(container: modelContainer)
        let albumRepo = SwiftDataAlbumRepository(container: modelContainer)
        return DataServicesBundle(
            location: location,
            photoLibraryExporter: photoLibraryExporter,
            photoLibrary: photoLibrary,
            tutorialPhotoStore: tutorialPhotoStore,
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            zipExporter: ZipExporterAdapter(
                photoLibrary: photoLibrary,
                pairRepo: pairRepo,
                appSettings: appSettings,
            ),
        )
    }

    static func makeAdServices(
        trackingService: TrackingAuthorizationService,
        tutorialCoordinator: TutorialCoordinator,
        overrides: AdServicesOverrides,
    ) -> AdServicesBundle {
        AdServicesBundle(
            interstitial: overrides.interstitial
                ?? InterstitialAdManager(
                    trackingService: trackingService,
                    tutorialCoordinator: tutorialCoordinator,
                ),
            rewarded: overrides.rewarded
                ?? RewardedAdManager(
                    trackingService: trackingService,
                    tutorialCoordinator: tutorialCoordinator,
                ),
            nativeAd: overrides.nativeAd
                ?? NativeAdLoader(
                    trackingService: trackingService,
                    tutorialCoordinator: tutorialCoordinator,
                ),
            appOpen: overrides.appOpen
                ?? AppOpenAdManager(
                    trackingService: trackingService,
                    tutorialCoordinator: tutorialCoordinator,
                ),
            fullscreen: overrides.fullscreen ?? FullscreenAdCoordinator(),
            consent: overrides.consent ?? ConsentManager(),
        )
    }

    static func makeSubscriptionServices(
        overrides: SubscriptionServicesOverrides,
    ) -> SubscriptionServicesBundle {
        let scheduler = RenewalReminderScheduler()
        return SubscriptionServicesBundle(
            productsService: overrides.productsService ?? ProductsService(),
            subscriptionStore: overrides.subscriptionStore
                ?? SubscriptionStore(renewalReminderScheduler: scheduler),
            transactionListener: overrides.transactionListener ?? TransactionListener(),
        )
    }

    static func makeUseCases(
        dependencies: UseCasesDependencies,
    ) -> UseCasesBundle {
        let pairRepo = dependencies.pairRepo
        let photoLibrary = dependencies.photoLibrary
        let tutorialPhotoStore = dependencies.tutorialPhotoStore
        let captureAfter = CaptureAfterUseCase(
            pairRepo: pairRepo,
            photoLibrary: photoLibrary,
            tutorialPhotoStore: tutorialPhotoStore,
        )
        let exportPairs = ExportPairsUseCase(zipExporter: dependencies.zipExporter)
        let deleteAfterPhoto = DeleteAfterPhotoUseCase(
            pairRepo: pairRepo,
            photoLibrary: photoLibrary,
        )
        let deletePairsKeepingCombined = DeletePairsKeepingCombinedUseCase(
            pairRepo: pairRepo,
            photoLibrary: photoLibrary,
        )
        return UseCasesBundle(
            createPair: CreatePairUseCase(
                pairRepo: pairRepo,
                photoLibrary: photoLibrary,
                location: dependencies.location,
                tutorialPhotoStore: tutorialPhotoStore,
            ),
            captureAfter: captureAfter,
            deleteAfterPhoto: deleteAfterPhoto,
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
                membership: dependencies.membership,
            ),
        )
    }
}
