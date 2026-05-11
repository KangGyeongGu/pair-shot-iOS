import Foundation
import SwiftData

extension AppEnvironment {
    static func makeDataServices(
        modelContainer: ModelContainer,
        appSettings: AppSettings
    ) -> (
        location: CoreLocationService,
        photoLibraryExporter: PhotoLibraryExport,
        photoLibrary: PhotoLibraryService,
        photoLibrarySync: PhotoLibrarySyncService,
        pairRepo: PhotoPairRepository,
        albumRepo: AlbumRepository,
        zipExporter: ZipExporterAdapter
    ) {
        let location = CoreLocationService()
        let photoLibraryExporter = PhotoLibraryExport()
        let photoLibrary = PhotoLibraryService()
        let pairRepo = SwiftDataPhotoPairRepository(container: modelContainer)
        let albumRepo = SwiftDataAlbumRepository(container: modelContainer)
        return (
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
        overrides: (
            interstitial: InterstitialAdManager?,
            rewarded: RewardedAdManager?,
            nativeAd: NativeAdLoader?,
            appOpen: AppOpenAdManager?,
            fullscreen: FullscreenAdCoordinator?,
            consent: ConsentManager?
        )
    ) -> (
        interstitial: InterstitialAdManager,
        rewarded: RewardedAdManager,
        nativeAd: NativeAdLoader,
        appOpen: AppOpenAdManager,
        fullscreen: FullscreenAdCoordinator,
        consent: ConsentManager
    ) {
        (
            interstitial: overrides.interstitial ?? InterstitialAdManager(trackingService: trackingService),
            rewarded: overrides.rewarded ?? RewardedAdManager(trackingService: trackingService),
            nativeAd: overrides.nativeAd ?? NativeAdLoader(trackingService: trackingService),
            appOpen: overrides.appOpen ?? AppOpenAdManager(trackingService: trackingService),
            fullscreen: overrides.fullscreen ?? FullscreenAdCoordinator(),
            consent: overrides.consent ?? ConsentManager()
        )
    }

    static func makeUseCases(
        pairRepo: PhotoPairRepository,
        albumRepo: AlbumRepository,
        photoLibrary: PhotoLibraryService,
        photoLibraryExporter: PhotoLibraryExport,
        location: CoreLocationService,
        zipExporter: ZipExporterAdapter,
        snackbarQueue: SnackbarQueue,
        appSettings: AppSettings
    ) -> (
        createPair: CreatePairUseCase,
        captureAfter: CaptureAfterUseCase,
        recaptureAfter: RecaptureAfterUseCase,
        deletePairs: DeletePairsUseCase,
        deleteCombinedExports: DeleteCombinedExportsUseCase,
        deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase,
        exportPairs: ExportPairsUseCase,
        toggleAlbumMembership: ToggleAlbumMembershipUseCase,
        immediateExport: ImmediateExportService
    ) {
        let captureAfter = CaptureAfterUseCase(pairRepo: pairRepo, photoLibrary: photoLibrary)
        let exportPairs = ExportPairsUseCase(pairRepo: pairRepo, zipExporter: zipExporter)
        return (
            createPair: CreatePairUseCase(pairRepo: pairRepo, photoLibrary: photoLibrary, location: location),
            captureAfter: captureAfter,
            recaptureAfter: RecaptureAfterUseCase(pairRepo: pairRepo, photoLibrary: photoLibrary, captureAfter: captureAfter),
            deletePairs: DeletePairsUseCase(pairRepo: pairRepo, photoLibrary: photoLibrary),
            deleteCombinedExports: DeleteCombinedExportsUseCase(pairRepo: pairRepo, photoLibrary: photoLibrary),
            deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase(pairRepo: pairRepo, photoLibrary: photoLibrary),
            exportPairs: exportPairs,
            toggleAlbumMembership: ToggleAlbumMembershipUseCase(albumRepo: albumRepo),
            immediateExport: ImmediateExportService(
                photoLibrary: photoLibrary,
                exportPairs: exportPairs,
                photoLibraryExporter: photoLibraryExporter,
                snackbarQueue: snackbarQueue,
                appSettings: appSettings,
                pairRepo: pairRepo
            )
        )
    }
}
