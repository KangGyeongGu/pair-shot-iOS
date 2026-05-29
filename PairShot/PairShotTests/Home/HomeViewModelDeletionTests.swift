import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct HomeViewModelDeletionTests {
    @Test
    func `requestPairDeletion 단일 선택 → pendingPairDelete 1건 세팅`() {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        viewModel.isSelectionMode = true
        viewModel.selectedPairIds = [pair.id]

        viewModel.requestPairDeletion(from: [pair])

        #expect(viewModel.pendingPairDelete?.pairs.count == 1)
        #expect(viewModel.pendingPairDelete?.pairs.first?.id == pair.id)
    }

    @Test
    func `requestPairDeletion 다중 선택 → pendingPairDelete 가 count 보존`() {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let p1 = FixturePhotoPair.make()
        let p2 = FixturePhotoPair.make()
        let p3 = FixturePhotoPair.make()
        viewModel.isSelectionMode = true
        viewModel.selectedPairIds = [p1.id, p2.id]

        viewModel.requestPairDeletion(from: [p1, p2, p3])

        #expect(viewModel.pendingPairDelete?.pairs.count == 2)
        let ids = Set((viewModel.pendingPairDelete?.pairs ?? []).map(\.id))
        #expect(ids == Set([p1.id, p2.id]))
    }

    @Test
    func `requestPairDeletion 빈 selection → pendingPairDelete 미세팅`() {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()

        viewModel.requestPairDeletion(from: [pair])

        #expect(viewModel.pendingPairDelete == nil)
    }

    @Test
    func `confirmPairDeletion → DeletePairs UseCase 호출 + 선택 모드 해제`() async throws {
        let env = HomeDeletionEnvironment()
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
    func `confirmOriginalOnlyPairDeletion → DeletePairsKeepingCombined 경로 호출`() async throws {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)

        await viewModel.confirmOriginalOnlyPairDeletion(pairs: [pair])

        #expect(!env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
    }

    @Test
    func `confirmCombinedDeletion → DeleteCombinedExports 만 호출 + pair entity 보존`() async throws {
        let env = HomeDeletionEnvironment()
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
    func `confirmSinglePairDeletion → 단일 id Set 으로 DeletePairs 호출, cancelSelection 미호출`() async throws {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        viewModel.isSelectionMode = true
        viewModel.selectedPairIds = [UUID()]

        await viewModel.confirmSinglePairDeletion(pair)

        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
        #expect(viewModel.isSelectionMode)
    }

    @Test
    func `requestAlbumDeletion 단일 선택 → pendingAlbumDelete 1건 세팅`() {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let album = Album(name: "A")
        viewModel.isSelectionMode = true
        viewModel.selectedAlbumIds = [album.id]

        viewModel.requestAlbumDeletion(from: [album])

        #expect(viewModel.pendingAlbumDelete?.albums.count == 1)
        #expect(viewModel.pendingAlbumDelete?.albums.first?.id == album.id)
    }

    @Test
    func `requestAlbumDeletion 다중 선택 + 빈 selection → 분기 확인`() {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let a1 = Album(name: "A1")
        let a2 = Album(name: "A2")

        viewModel.requestAlbumDeletion(from: [a1, a2])
        #expect(viewModel.pendingAlbumDelete == nil)

        viewModel.isSelectionMode = true
        viewModel.selectedAlbumIds = [a1.id, a2.id]
        viewModel.requestAlbumDeletion(from: [a1, a2])
        #expect(viewModel.pendingAlbumDelete?.albums.count == 2)
    }

    @Test
    func `confirmAlbumDeletion → AlbumRepository delete 만 호출 (pair UseCase 미호출) + selection clear`() async throws {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        let album = Album(name: "A", pairIds: [pair.id])
        try await env.albumRepo.add(album)
        viewModel.isSelectionMode = true
        viewModel.selectedAlbumIds = [album.id]

        await viewModel.confirmAlbumDeletion(albums: [album])

        #expect(env.albumRepo.deleteCalls == [album.id])
        #expect(!env.repo.callLog.contains(.delete(ids: [pair.id])))
        let pairStill = try await env.repo.fetch(id: pair.id)
        #expect(pairStill != nil)
        #expect(!viewModel.isSelectionMode)
        #expect(viewModel.selectedAlbumIds.isEmpty)
    }

    @Test
    func `confirmAlbumDeletionAllPairs → DeletePairs(ids) + AlbumRepository delete`() async throws {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        let album = Album(name: "A", pairIds: [pair.id])
        try await env.albumRepo.add(album)

        await viewModel.confirmAlbumDeletionAllPairs(albums: [album])

        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
        #expect(env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.albumRepo.deleteCalls == [album.id])
    }

    @Test
    func `confirmAlbumDeletionOriginalOnly → DeletePairsKeepingCombined + AlbumRepository delete`() async throws {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        let album = Album(name: "A", pairIds: [pair.id])
        try await env.albumRepo.add(album)

        await viewModel.confirmAlbumDeletionOriginalOnly(albums: [album])

        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
        #expect(!env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.albumRepo.deleteCalls == [album.id])
    }

    @Test
    func `confirmAlbumDeletionCombinedOnly → DeleteCombinedExports + AlbumRepository delete (pair entity 보존)`(
    ) async throws {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make(hasCombinedExport: true)
        try await env.repo.add(pair)
        try await env.repo.recordExportHistory(
            pairId: pair.id,
            kind: .combined,
            photoLocalIdentifier: "combined",
        )
        let album = Album(name: "A", pairIds: [pair.id])
        try await env.albumRepo.add(album)

        await viewModel.confirmAlbumDeletionCombinedOnly(albums: [album])

        #expect(env.repo.callLog.contains(.deleteCombinedExportRecords(ids: [pair.id])))
        #expect(!env.repo.callLog.contains(.delete(ids: [pair.id])))
        #expect(env.albumRepo.deleteCalls == [album.id])
        let preserved = try await env.repo.fetch(id: pair.id)
        #expect(preserved != nil)
    }

    @Test
    func `confirmAlbumDeletion 빈 pairIds 분기 → 모든 변형이 pair UseCase 미호출`() async throws {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let album = Album(name: "Empty", pairIds: [])
        try await env.albumRepo.add(album)

        await viewModel.confirmAlbumDeletionAllPairs(albums: [album])

        #expect(!env.repo.callLog.contains(where: {
            if case .delete = $0 { true } else { false }
        }))
        #expect(env.albumRepo.deleteCalls == [album.id])
    }

    @Test
    func `confirmSingleAlbumDeletionAllPairs → 단일 album 의 pairIds 처리`() async throws {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        let album = Album(name: "A", pairIds: [pair.id])
        try await env.albumRepo.add(album)

        await viewModel.confirmSingleAlbumDeletionAllPairs(album)

        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
        #expect(env.albumRepo.deleteCalls == [album.id])
    }

    @Test
    func `confirmSingleAlbumDeletion → AlbumRepository delete 만 호출`() async throws {
        let env = HomeDeletionEnvironment()
        let viewModel = env.makeViewModel()
        let album = Album(name: "A")
        try await env.albumRepo.add(album)

        await viewModel.confirmSingleAlbumDeletion(album)

        #expect(env.albumRepo.deleteCalls == [album.id])
        #expect(env.repo.callLog.isEmpty)
    }
}

@MainActor
private final class HomeDeletionEnvironment {
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
    let location: CoreLocationService

    init() {
        let suiteName = "home-deletion-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        appSettings = AppSettings(defaults: defaults)
        snackbarQueue = SnackbarQueue()
        repo = PairDeletionRecordingRepo(backing: InMemoryPhotoPairRepo())
        albumRepo = AlbumDeletionRecordingRepo()
        photoLibrary = PhotoLibraryService()
        thumbnailCache = PhotoLibraryThumbnailCache()
        location = CoreLocationService()
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

    func makeViewModel() -> HomeViewModel {
        HomeViewModel(
            pairRepo: repo,
            albumRepo: albumRepo,
            deletePairs: DeletePairsUseCase(pairRepo: repo, photoLibrary: photoLibrary),
            deleteAfterPhoto: DeleteAfterPhotoUseCase(pairRepo: repo, photoLibrary: photoLibrary),
            location: location,
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

@MainActor
final class AlbumDeletionRecordingRepo: AlbumRepository, @unchecked Sendable {
    private(set) var deleteCalls: [UUID] = []
    private(set) var updateCalls: [UUID] = []
    private(set) var addCalls: [UUID] = []
    private(set) var addPairCalls: [(pairId: UUID, albumId: UUID)] = []
    private(set) var removePairCalls: [(pairId: UUID, albumId: UUID)] = []
    private var albums: [UUID: Album] = [:]

    func add(_ album: Album) async throws {
        addCalls.append(album.id)
        albums[album.id] = album
    }

    func update(_ album: Album) async throws {
        updateCalls.append(album.id)
        albums[album.id] = album
    }

    func delete(id: UUID) async throws {
        deleteCalls.append(id)
        albums.removeValue(forKey: id)
    }

    func addPair(pairId: UUID, toAlbum albumId: UUID) async throws {
        addPairCalls.append((pairId, albumId))
    }

    func removePair(pairId: UUID, fromAlbum albumId: UUID) async throws {
        removePairCalls.append((pairId, albumId))
    }
}
