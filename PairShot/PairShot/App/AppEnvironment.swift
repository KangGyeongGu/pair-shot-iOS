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
    let couponVerifier: CouponVerifying
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
        fullscreenAdCoordinator: FullscreenAdCoordinator? = nil
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

        let services = AppServiceBundle.make()
        storage = services.storage
        photoStorageService = services.photoStorageService
        location = services.location
        fileNameBuilder = services.fileNameBuilder
        exifNormalizer = services.exifNormalizer
        couponVerifier = services.couponVerifier
        photoLibraryExporter = services.photoLibraryExporter

        let repositories = AppRepositoryBundle.make(container: modelContainer)
        pairRepo = repositories.pairRepo
        albumRepo = repositories.albumRepo
        couponRepo = repositories.couponRepo

        zipExporter = ZipExporterAdapter(
            storage: services.photoStorageService,
            pairRepo: repositories.pairRepo
        )

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
        retakeMode: Bool = false
    ) -> AfterCameraViewModel {
        AfterCameraViewModel(
            albumId: albumId,
            initialPairId: initialPairId,
            retakeMode: retakeMode,
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
            storage: photoStorageService
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
            exportPairs: exportPairs,
            toggleAlbumMembership: toggleAlbumMembership,
            storage: photoStorageService,
            location: location
        )
    }

    func makeComparisonViewModel(
        pairs: [PhotoPair],
        startIndex: Int
    ) -> ComparisonViewModel {
        ComparisonViewModel(
            pairs: pairs,
            startIndex: startIndex,
            pairRepo: pairRepo,
            appSettings: appSettings,
            storage: photoStorageService
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

    func makeExportPickerViewModel(
        pairs: [PhotoPair],
        storage: PhotoStorageService
    ) -> ExportPickerViewModel {
        ExportPickerViewModel(
            pairs: pairs,
            storage: storage,
            exportPairs: exportPairs,
            photoLibrary: photoLibraryExporter
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
    let couponVerifier: CouponVerifying
    let photoLibraryExporter: any PhotoLibraryExporting

    static func make() -> Self {
        let storage = PhotoStorageService()
        return Self(
            storage: storage,
            photoStorageService: storage,
            location: LocationFetcherAdapter(provider: CoreLocationService()),
            fileNameBuilder: FileNameBuilderAdapter(),
            exifNormalizer: ExifNormalizerAdapter(),
            couponVerifier: CouponVerifierAdapter(),
            photoLibraryExporter: PhotoLibraryExport()
        )
    }
}

@MainActor
struct AppRepositoryBundle {
    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let couponRepo: CouponRepository

    static func make(container: ModelContainer) -> Self {
        Self(
            pairRepo: SwiftDataPhotoPairRepository(container: container),
            albumRepo: SwiftDataAlbumRepository(container: container),
            couponRepo: SwiftDataCouponRepository(container: container)
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
                couponRepo: repositories.couponRepo,
                verifier: services.couponVerifier,
                defaultDurationDays: CouponRegistrationViewModel.defaultDurationDays
            ),
            checkAdFreeState: CheckAdFreeStateUseCase(
                couponRepo: repositories.couponRepo
            )
        )
    }
}
