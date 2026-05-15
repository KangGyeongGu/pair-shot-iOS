import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppEnvironment {
    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository

    let location: CoreLocationService
    let couponApiConfig: CouponApiConfig
    let deviceHashProvider: DeviceHashProvider
    let photoLibraryExporter: PhotoLibraryExport
    let photoLibrary: PhotoLibraryService

    let createPair: CreatePairUseCase
    let captureAfter: CaptureAfterUseCase
    let recaptureAfter: RecaptureAfterUseCase
    let deletePairs: DeletePairsUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase
    let deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase
    let exportPairs: ExportPairsUseCase

    let appSettings: AppSettings
    let appSettingsRepo: AppSettingsRepository
    let promotionStore: PromotionStore
    let trackingService: TrackingAuthorizationService

    let interstitialAdManager: InterstitialAdManager
    let rewardedAdManager: RewardedAdManager
    let nativeAdLoader: NativeAdLoader
    let appOpenAdManager: AppOpenAdManager
    let fullscreenAdCoordinator: FullscreenAdCoordinator
    let consentManager: ConsentManager

    let snackbarQueue: SnackbarQueue
    let immediateExport: ImmediateExportService
    let settingsRedirectCoordinator: SettingsRedirectCoordinator
    let exportCompletionCoordinator: ExportCompletionCoordinator
    let permissionStatusService: PermissionStatusService
    let thumbnailCache: PhotoLibraryThumbnailCache
    let hapticService: HapticService
    let motionService: MotionService

    let productsService: ProductsService
    let subscriptionStore: SubscriptionStore
    let transactionListener: TransactionListener

    let membership: Membership

    private var sharedSettingsViewModel: SettingsViewModel?

    init(
        modelContainer: ModelContainer,
        appSettings: AppSettings? = nil,
        appSettingsRepo: AppSettingsRepository? = nil,
        promotionStore: PromotionStore? = nil,
        trackingService: TrackingAuthorizationService? = nil,
        interstitialAdManager: InterstitialAdManager? = nil,
        rewardedAdManager: RewardedAdManager? = nil,
        nativeAdLoader: NativeAdLoader? = nil,
        appOpenAdManager: AppOpenAdManager? = nil,
        fullscreenAdCoordinator: FullscreenAdCoordinator? = nil,
        consentManager: ConsentManager? = nil,
        snackbarQueue: SnackbarQueue? = nil,
        settingsRedirectCoordinator: SettingsRedirectCoordinator? = nil,
        exportCompletionCoordinator: ExportCompletionCoordinator? = nil,
        permissionStatusService: PermissionStatusService? = nil,
        thumbnailCache: PhotoLibraryThumbnailCache? = nil,
        hapticService: HapticService? = nil,
        motionService: MotionService? = nil,
        productsService: ProductsService? = nil,
        subscriptionStore: SubscriptionStore? = nil,
        transactionListener: TransactionListener? = nil
    ) {
        let bundles = Self.makeAllBundles(
            input: AppEnvironmentInitInput(
                modelContainer: modelContainer,
                foundationOverrides: AppEnvironmentFoundationOverrides(
                    appSettings: appSettings,
                    snackbarQueue: snackbarQueue,
                    appSettingsRepo: appSettingsRepo,
                    promotionStore: promotionStore,
                    trackingService: trackingService,
                    settingsRedirectCoordinator: settingsRedirectCoordinator,
                    exportCompletionCoordinator: exportCompletionCoordinator,
                    permissionStatusService: permissionStatusService,
                    thumbnailCache: thumbnailCache,
                    hapticService: hapticService,
                    motionService: motionService
                ),
                adServicesOverrides: AdServicesOverrides(
                    interstitial: interstitialAdManager,
                    rewarded: rewardedAdManager,
                    nativeAd: nativeAdLoader,
                    appOpen: appOpenAdManager,
                    fullscreen: fullscreenAdCoordinator,
                    consent: consentManager
                ),
                subscriptionOverrides: SubscriptionServicesOverrides(
                    productsService: productsService,
                    subscriptionStore: subscriptionStore,
                    transactionListener: transactionListener
                )
            )
        )
        let foundation = bundles.foundation
        self.appSettings = foundation.appSettings
        self.appSettingsRepo = foundation.appSettingsRepo
        self.promotionStore = foundation.promotionStore
        self.trackingService = foundation.trackingService
        self.snackbarQueue = foundation.snackbarQueue
        self.settingsRedirectCoordinator = foundation.settingsRedirectCoordinator
        self.exportCompletionCoordinator = foundation.exportCompletionCoordinator
        self.permissionStatusService = foundation.permissionStatusService
        self.thumbnailCache = foundation.thumbnailCache
        self.hapticService = foundation.hapticService
        self.motionService = foundation.motionService
        couponApiConfig = foundation.apiConfig
        deviceHashProvider = foundation.deviceHashProvider

        let adServices = bundles.adServices
        self.interstitialAdManager = adServices.interstitial
        self.rewardedAdManager = adServices.rewarded
        self.nativeAdLoader = adServices.nativeAd
        self.appOpenAdManager = adServices.appOpen
        self.fullscreenAdCoordinator = adServices.fullscreen
        self.consentManager = adServices.consent

        let dataServices = bundles.dataServices
        location = dataServices.location
        photoLibraryExporter = dataServices.photoLibraryExporter
        photoLibrary = dataServices.photoLibrary
        pairRepo = dataServices.pairRepo
        albumRepo = dataServices.albumRepo

        let useCases = bundles.useCases
        createPair = useCases.createPair
        captureAfter = useCases.captureAfter
        recaptureAfter = useCases.recaptureAfter
        deletePairs = useCases.deletePairs
        deleteCombinedExports = useCases.deleteCombinedExports
        deletePairsKeepingCombined = useCases.deletePairsKeepingCombined
        exportPairs = useCases.exportPairs
        immediateExport = useCases.immediateExport

        let subscription = bundles.subscription
        self.productsService = subscription.productsService
        self.subscriptionStore = subscription.subscriptionStore
        self.transactionListener = subscription.transactionListener

        membership = bundles.membership
    }

    func makeBeforeCameraViewModel(
        albumId: UUID?,
        refillPairId: UUID? = nil
    ) -> BeforeCameraViewModel {
        BeforeCameraViewModel(
            albumId: albumId,
            createPair: createPair,
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            appSettings: appSettings,
            hapticService: hapticService,
            location: location,
            membership: membership,
            sortOrder: HomeSortOrderMapping.sortOrder(from: appSettings.homeSortOrder),
            refillPairId: refillPairId,
            session: makeCameraSession(),
            permissionProbe: makeCameraPermissionProbe()
        )
    }

    func makeAfterCameraViewModel(
        albumId: UUID?,
        initialPairId: UUID? = nil,
        sortOrder: HomeSortOrder = .newest,
        recaptureTargetPair: PhotoPair? = nil
    ) -> AfterCameraViewModel {
        AfterCameraViewModel(
            albumId: albumId,
            captureAfter: captureAfter,
            recaptureAfter: recaptureAfter,
            pairRepo: pairRepo,
            photoLibrary: photoLibrary,
            appSettings: appSettings,
            hapticService: hapticService,
            location: location,
            initialPairId: initialPairId,
            sortOrder: sortOrder,
            recaptureTargetPair: recaptureTargetPair,
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
            appSettings: appSettings,
            membership: membership
        )
    }

    func makeAlbumDetailViewModel(albumId: UUID) -> AlbumDetailViewModel {
        AlbumDetailViewModel(
            albumId: albumId,
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            deletePairs: deletePairs,
            immediateExport: immediateExport,
            appSettings: appSettings,
            thumbnailCache: thumbnailCache,
            interstitialAdManager: interstitialAdManager,
            membership: membership,
            fullscreenAdCoordinator: fullscreenAdCoordinator,
            deleteCombinedExports: deleteCombinedExports,
            deletePairsKeepingCombined: deletePairsKeepingCombined
        )
    }

    func makePairPickerViewModel(albumId: UUID) -> PairPickerViewModel {
        PairPickerViewModel(
            albumId: albumId,
            albumRepo: albumRepo,
            photoLibrary: photoLibrary
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            pairRepo: pairRepo,
            albumRepo: albumRepo,
            deletePairs: deletePairs,
            location: location,
            immediateExport: immediateExport,
            appSettings: appSettings,
            thumbnailCache: thumbnailCache,
            interstitialAdManager: interstitialAdManager,
            membership: membership,
            fullscreenAdCoordinator: fullscreenAdCoordinator,
            deleteCombinedExports: deleteCombinedExports,
            deletePairsKeepingCombined: deletePairsKeepingCombined
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        if let sharedSettingsViewModel { return sharedSettingsViewModel }
        let viewModel = SettingsViewModel(
            appSettings: appSettings,
            membership: membership
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

    func makeExportSettingsViewModel(pairIds: [UUID]) -> ExportSettingsViewModel {
        ExportSettingsViewModel(
            pairIds: pairIds,
            pairRepo: pairRepo,
            photoLibrary: photoLibrary,
            exportPairs: exportPairs,
            photoLibraryExporter: photoLibraryExporter,
            snackbarQueue: snackbarQueue,
            appSettings: appSettings,
            interstitialAdManager: interstitialAdManager,
            membership: membership,
            fullscreenAdCoordinator: fullscreenAdCoordinator
        )
    }
}
