import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct AlbumDetailViewModelDeletionTests {
    @Test
    func `confirmPairDeletion → DeletePairs UseCase 호출 + selection 모드 해제`() async throws {
        let env = AlbumDetailDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        viewModel.isSelectionMode = true
        viewModel.selectedPairIds = [pair.id]

        await viewModel.confirmPairDeletion(pairs: [pair])

        #expect(env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
        #expect(!viewModel.isSelectionMode)
        #expect(viewModel.selectedPairIds.isEmpty)
    }

    @Test
    func `confirmPairDeletion 다중 pair → 모든 ids 한 번에 전달`() async throws {
        let env = AlbumDetailDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let p1 = FixturePhotoPair.make()
        let p2 = FixturePhotoPair.make()
        try await env.repo.add(p1)
        try await env.repo.add(p2)

        await viewModel.confirmPairDeletion(pairs: [p1, p2])

        let deleteCalls = env.repo.callLog.compactMap {
            if case let .delete(ids) = $0 { ids } else { nil }
        }
        #expect(deleteCalls.first == Set([p1.id, p2.id]))
    }

    @Test
    func `confirmOriginalOnlyDeletion → DeletePairsKeepingCombined 경로 호출`() async throws {
        let env = AlbumDetailDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)

        await viewModel.confirmOriginalOnlyDeletion(pairs: [pair])

        #expect(!env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
    }

    @Test
    func `confirmCombinedDeletion → DeleteCombinedExports 만 호출 + pair entity 보존`() async throws {
        let env = AlbumDetailDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make(hasCombinedExport: true)
        try await env.repo.add(pair)
        try await env.repo.recordExportHistory(
            pairId: pair.id,
            kind: .combined,
            photoLocalIdentifier: "combined",
        )

        await viewModel.confirmCombinedDeletion(pairs: [pair])

        #expect(env.repo.callLog.contains(.combinedExportPhotoIdentifiers))
        #expect(env.repo.callLog.contains(.deleteCombinedExportRecords(ids: [pair.id])))
        let preserved = try await env.repo.fetch(id: pair.id)
        #expect(preserved != nil)
    }

    @Test
    func `confirmSinglePairDeletion → DeletePairs 단일 id, cancelSelection 미호출`() async throws {
        let env = AlbumDetailDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        viewModel.isSelectionMode = true

        await viewModel.confirmSinglePairDeletion(pair)

        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
        #expect(viewModel.isSelectionMode)
    }

    @Test
    func `confirmSingleOriginalOnlyDeletion → DeletePairsKeepingCombined 단일 id`() async throws {
        let env = AlbumDetailDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)

        await viewModel.confirmSingleOriginalOnlyDeletion(pair)

        #expect(!env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
    }

    @Test
    func `confirmSingleCombinedDeletion → DeleteCombinedExports 단일 id`() async throws {
        let env = AlbumDetailDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make(hasCombinedExport: true)
        try await env.repo.add(pair)
        try await env.repo.recordExportHistory(
            pairId: pair.id,
            kind: .combined,
            photoLocalIdentifier: "combined",
        )

        await viewModel.confirmSingleCombinedDeletion(pair)

        #expect(env.repo.callLog.contains(.deleteCombinedExportRecords(ids: [pair.id])))
        let preserved = try await env.repo.fetch(id: pair.id)
        #expect(preserved != nil)
    }

    @Test
    func `confirmAlbumDeletion → AlbumRepository delete + albumDeleted true (pair UseCase 미호출)`() async {
        let albumId = UUID()
        let env = AlbumDetailDeletionEnvironment(albumId: albumId)
        let viewModel = env.makeViewModel()

        await viewModel.confirmAlbumDeletion()

        #expect(env.albumRepo.deleteCalls == [albumId])
        #expect(viewModel.albumDeleted)
        #expect(env.repo.callLog.isEmpty)
    }

    @Test
    func `confirmAlbumDeletionAllPairs → DeletePairs(ids) + AlbumRepository delete + albumDeleted true`() async throws {
        let albumId = UUID()
        let env = AlbumDetailDeletionEnvironment(albumId: albumId)
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        let album = Album(name: "A", id: albumId, pairIds: [pair.id])

        await viewModel.confirmAlbumDeletionAllPairs(album: album)

        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
        #expect(env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.albumRepo.deleteCalls == [albumId])
        #expect(viewModel.albumDeleted)
    }

    @Test
    func `confirmAlbumDeletionOriginalOnly → DeletePairsKeepingCombined + AlbumRepository delete`() async throws {
        let albumId = UUID()
        let env = AlbumDetailDeletionEnvironment(albumId: albumId)
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        let album = Album(name: "A", id: albumId, pairIds: [pair.id])

        await viewModel.confirmAlbumDeletionOriginalOnly(album: album)

        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
        #expect(!env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.albumRepo.deleteCalls == [albumId])
        #expect(viewModel.albumDeleted)
    }

    @Test
    func `confirmAlbumDeletionCombinedOnly → DeleteCombinedExports + AlbumRepository delete (pair 보존)`() async throws {
        let albumId = UUID()
        let env = AlbumDetailDeletionEnvironment(albumId: albumId)
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make(hasCombinedExport: true)
        try await env.repo.add(pair)
        try await env.repo.recordExportHistory(
            pairId: pair.id,
            kind: .combined,
            photoLocalIdentifier: "combined",
        )
        let album = Album(name: "A", id: albumId, pairIds: [pair.id])

        await viewModel.confirmAlbumDeletionCombinedOnly(album: album)

        #expect(env.repo.callLog.contains(.deleteCombinedExportRecords(ids: [pair.id])))
        #expect(!env.repo.callLog.contains(.delete(ids: [pair.id])))
        #expect(env.albumRepo.deleteCalls == [albumId])
        let preserved = try await env.repo.fetch(id: pair.id)
        #expect(preserved != nil)
    }

    @Test
    func `confirmAlbumDeletion 변형 빈 pairIds 분기 → pair UseCase 미호출`() async {
        let albumId = UUID()
        let env = AlbumDetailDeletionEnvironment(albumId: albumId)
        let viewModel = env.makeViewModel()
        let album = Album(name: "Empty", id: albumId, pairIds: [])

        await viewModel.confirmAlbumDeletionAllPairs(album: album)

        #expect(!env.repo.callLog.contains(where: {
            if case .delete = $0 { true } else { false }
        }))
        #expect(env.albumRepo.deleteCalls == [albumId])
    }
}

@MainActor
private final class AlbumDetailDeletionEnvironment {
    let albumId: UUID
    let repo: PairDeletionRecordingRepo
    let albumRepo: AlbumDeletionRecordingRepo
    let photoLibrary: PhotoLibraryService
    let thumbnailCache: PhotoLibraryThumbnailCache
    let appSettings: AppSettings
    let snackbarQueue: SnackbarQueue
    let membership: Membership
    let interstitial: InterstitialAdManager
    let fullscreenAd: FullscreenAdCoordinator
    let immediateExport: ImmediateExportService

    init(albumId: UUID = UUID()) {
        self.albumId = albumId
        let suiteName = "albumdetail-deletion-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        appSettings = AppSettings(defaults: defaults)
        snackbarQueue = SnackbarQueue()
        repo = PairDeletionRecordingRepo(backing: InMemoryPhotoPairRepo())
        albumRepo = AlbumDeletionRecordingRepo()
        photoLibrary = PhotoLibraryService()
        thumbnailCache = PhotoLibraryThumbnailCache()
        let promotionStore = PromotionStore(
            fetcher: PromotionFetcher(config: CouponApiConfig.resolve()),
            deviceHashProvider: DeviceHashProvider(),
        )
        let subscriptionStore = SubscriptionStore(renewalReminderScheduler: RenewalReminderScheduler())
        membership = Membership(subscriptionStore: subscriptionStore, promotionStore: promotionStore)
        let tracking = TrackingAuthorizationService()
        let tutorialCoordinator = TutorialCoordinator()
        interstitial = InterstitialAdManager(
            trackingService: tracking,
            tutorialCoordinator: tutorialCoordinator,
        )
        fullscreenAd = FullscreenAdCoordinator()
        let exportPairs = ExportPairsUseCase(
            zipExporter: ZipExporterAdapter(
                photoLibrary: photoLibrary,
                pairRepo: repo,
                appSettings: appSettings,
            ),
        )
        immediateExport = ImmediateExportService(
            photoLibrary: photoLibrary,
            exportPairs: exportPairs,
            photoLibraryExporter: PhotoLibraryExport(),
            snackbarQueue: snackbarQueue,
            appSettings: appSettings,
            pairRepo: repo,
            membership: membership,
        )
    }

    func makeViewModel() -> AlbumDetailViewModel {
        AlbumDetailViewModel(
            albumId: albumId,
            pairRepo: repo,
            albumRepo: albumRepo,
            deletePairs: DeletePairsUseCase(pairRepo: repo, photoLibrary: photoLibrary),
            immediateExport: immediateExport,
            appSettings: appSettings,
            thumbnailCache: thumbnailCache,
            interstitialAdManager: interstitial,
            membership: membership,
            fullscreenAdCoordinator: fullscreenAd,
            deleteCombinedExports: DeleteCombinedExportsUseCase(pairRepo: repo, photoLibrary: photoLibrary),
            deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase(
                pairRepo: repo,
                photoLibrary: photoLibrary,
            ),
            snackbarQueue: snackbarQueue,
        )
    }
}
