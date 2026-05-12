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
    let toggleAlbumMembership: ToggleAlbumMembershipUseCase

    let appSettings: AppSettings
    let appSettingsRepo: AppSettingsRepository
    let adFreeStore: AdFreeStore
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
    let permissionStatusService: PermissionStatusService
    let thumbnailCache: PhotoLibraryThumbnailCache
    let hapticService: HapticService
    let motionService: MotionService

    private var sharedSettingsViewModel: SettingsViewModel?

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
        consentManager: ConsentManager? = nil,
        snackbarQueue: SnackbarQueue? = nil,
        settingsRedirectCoordinator: SettingsRedirectCoordinator? = nil,
        permissionStatusService: PermissionStatusService? = nil,
        thumbnailCache: PhotoLibraryThumbnailCache? = nil,
        hapticService: HapticService? = nil,
        motionService: MotionService? = nil
    ) {
        let foundation = Self.makeFoundation(
            overrides: AppEnvironmentFoundationOverrides(
                appSettings: appSettings,
                snackbarQueue: snackbarQueue,
                appSettingsRepo: appSettingsRepo,
                adFreeStore: adFreeStore,
                trackingService: trackingService,
                settingsRedirectCoordinator: settingsRedirectCoordinator,
                permissionStatusService: permissionStatusService,
                thumbnailCache: thumbnailCache,
                hapticService: hapticService,
                motionService: motionService
            )
        )
        let resolvedAppSettings = foundation.appSettings
        let resolvedSnackbarQueue = foundation.snackbarQueue
        self.appSettings = resolvedAppSettings
        self.appSettingsRepo = foundation.appSettingsRepo
        self.adFreeStore = foundation.adFreeStore
        self.trackingService = foundation.trackingService
        self.snackbarQueue = resolvedSnackbarQueue
        self.settingsRedirectCoordinator = foundation.settingsRedirectCoordinator
        self.permissionStatusService = foundation.permissionStatusService
        self.thumbnailCache = foundation.thumbnailCache
        self.hapticService = foundation.hapticService
        self.motionService = foundation.motionService
        couponApiConfig = foundation.apiConfig
        deviceHashProvider = foundation.deviceHashProvider

        let adServices = Self.makeAdServices(
            trackingService: self.trackingService,
            overrides: AdServicesOverrides(
                interstitial: interstitialAdManager,
                rewarded: rewardedAdManager,
                nativeAd: nativeAdLoader,
                appOpen: appOpenAdManager,
                fullscreen: fullscreenAdCoordinator,
                consent: consentManager
            )
        )
        self.interstitialAdManager = adServices.interstitial
        self.rewardedAdManager = adServices.rewarded
        self.nativeAdLoader = adServices.nativeAd
        self.appOpenAdManager = adServices.appOpen
        self.fullscreenAdCoordinator = adServices.fullscreen
        self.consentManager = adServices.consent

        let dataServices = Self.makeDataServices(
            modelContainer: modelContainer,
            appSettings: resolvedAppSettings
        )
        location = dataServices.location
        photoLibraryExporter = dataServices.photoLibraryExporter
        photoLibrary = dataServices.photoLibrary
        pairRepo = dataServices.pairRepo
        albumRepo = dataServices.albumRepo

        let useCases = Self.makeUseCases(
            dependencies: UseCasesDependencies(
                pairRepo: dataServices.pairRepo,
                albumRepo: dataServices.albumRepo,
                photoLibrary: dataServices.photoLibrary,
                photoLibraryExporter: dataServices.photoLibraryExporter,
                location: dataServices.location,
                zipExporter: dataServices.zipExporter,
                snackbarQueue: resolvedSnackbarQueue,
                appSettings: resolvedAppSettings
            )
        )
        createPair = useCases.createPair
        captureAfter = useCases.captureAfter
        recaptureAfter = useCases.recaptureAfter
        deletePairs = useCases.deletePairs
        deleteCombinedExports = useCases.deleteCombinedExports
        deletePairsKeepingCombined = useCases.deletePairsKeepingCombined
        exportPairs = useCases.exportPairs
        toggleAlbumMembership = useCases.toggleAlbumMembership
        immediateExport = useCases.immediateExport
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
            adFreeStore: adFreeStore,
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
            adFreeStore: adFreeStore,
            fullscreenAdCoordinator: fullscreenAdCoordinator
        )
    }
}
