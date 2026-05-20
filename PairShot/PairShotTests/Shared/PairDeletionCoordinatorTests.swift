import Foundation
@testable import PairShot
import Testing

@MainActor
struct PairDeletionCoordinatorTests {
    @Test
    func `deletePairsWithThumbnailEviction → DeletePairs UseCase 호출 + ids 전달 + 빈 repo 후속`() async throws {
        let env = CoordinatorEnvironment()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        let coordinator = env.makeCoordinator()

        await coordinator.deletePairsWithThumbnailEviction([pair])

        #expect(env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
        let remaining = try await env.repo.fetch(id: pair.id)
        #expect(remaining == nil)
    }

    @Test
    func `deletePairsWithThumbnailEviction 다중 pair → 모든 ids 한 번에 전달`() async throws {
        let env = CoordinatorEnvironment()
        let p1 = FixturePhotoPair.make()
        let p2 = FixturePhotoPair.make()
        try await env.repo.add(p1)
        try await env.repo.add(p2)
        let coordinator = env.makeCoordinator()

        await coordinator.deletePairsWithThumbnailEviction([p1, p2])

        let deleteCalls = env.repo.callLog.compactMap {
            if case let .delete(ids) = $0 { ids } else { nil }
        }
        #expect(deleteCalls.count == 1)
        #expect(deleteCalls.first == Set([p1.id, p2.id]))
    }

    @Test
    func `deleteOriginalsKeepingCombined → allExportPhotoIdentifiers 미호출 (DeletePairs 와 차별화)`() async throws {
        let env = CoordinatorEnvironment()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        let coordinator = env.makeCoordinator()

        await coordinator.deleteOriginalsKeepingCombined([pair])

        #expect(!env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
    }

    @Test
    func `deleteCombinedOnly → combined export 식별자만 처리 + 원본 pair 는 repo 에 보존`() async throws {
        let env = CoordinatorEnvironment()
        let pair = FixturePhotoPair.make(hasCombinedExport: true)
        try await env.repo.add(pair)
        try await env.repo.recordExportHistory(
            pairId: pair.id,
            kind: .combined,
            photoLocalIdentifier: "combined-asset-id",
        )
        let coordinator = env.makeCoordinator()

        await coordinator.deleteCombinedOnly([pair])

        #expect(env.repo.callLog.contains(.combinedExportPhotoIdentifiers))
        #expect(env.repo.callLog.contains(.deleteCombinedExportRecords(ids: [pair.id])))
        let preserved = try await env.repo.fetch(id: pair.id)
        #expect(preserved != nil)
    }

    @Test
    func `deleteSinglePairWithThumbnailEviction → 단일 id Set 으로 DeletePairs 호출`() async throws {
        let env = CoordinatorEnvironment()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        let coordinator = env.makeCoordinator()

        await coordinator.deleteSinglePairWithThumbnailEviction(pair)

        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
        let remaining = try await env.repo.fetch(id: pair.id)
        #expect(remaining == nil)
    }

    @Test
    func `deleteSingleOriginalKeepingCombined → DeletePairsKeepingCombined 경로 호출`() async throws {
        let env = CoordinatorEnvironment()
        let pair = FixturePhotoPair.make()
        try await env.repo.add(pair)
        let coordinator = env.makeCoordinator()

        await coordinator.deleteSingleOriginalKeepingCombined(pair)

        #expect(!env.repo.callLog.contains(.allExportPhotoIdentifiers))
        #expect(env.repo.callLog.contains(.delete(ids: [pair.id])))
    }

    @Test
    func `deleteSingleCombinedOnly → combined records 만 제거, pair entity 보존`() async throws {
        let env = CoordinatorEnvironment()
        let pair = FixturePhotoPair.make(hasCombinedExport: true)
        try await env.repo.add(pair)
        try await env.repo.recordExportHistory(
            pairId: pair.id,
            kind: .combined,
            photoLocalIdentifier: "combined-asset-id",
        )
        let coordinator = env.makeCoordinator()

        await coordinator.deleteSingleCombinedOnly(pair)

        #expect(env.repo.callLog.contains(.deleteCombinedExportRecords(ids: [pair.id])))
        let preserved = try await env.repo.fetch(id: pair.id)
        #expect(preserved != nil)
    }

    @Test
    func `deletePairsWithThumbnailEviction 빈 배열 → UseCase 가 guard 로 no-op`() async {
        let env = CoordinatorEnvironment()
        let coordinator = env.makeCoordinator()

        await coordinator.deletePairsWithThumbnailEviction([])

        #expect(env.repo.callLog.isEmpty)
    }

    @Test
    func `evictThumbnails 빈 identifier 안전 처리 — guard 통과로 cache 영향 없음`() {
        let env = CoordinatorEnvironment()
        let coordinator = env.makeCoordinator()

        coordinator.evictThumbnails(beforeIdentifier: nil, afterIdentifier: nil)
        coordinator.evictThumbnails(beforeIdentifier: "", afterIdentifier: "")
        coordinator.evictThumbnails(beforeIdentifier: "before-only", afterIdentifier: nil)
    }
}

@MainActor
private final class CoordinatorEnvironment {
    let repo: PairDeletionRecordingRepo
    let photoLibrary: PhotoLibraryService
    let thumbnailCache: PhotoLibraryThumbnailCache

    init() {
        let backing = InMemoryPhotoPairRepo()
        repo = PairDeletionRecordingRepo(backing: backing)
        photoLibrary = PhotoLibraryService()
        thumbnailCache = PhotoLibraryThumbnailCache()
    }

    func makeCoordinator() -> PairDeletionCoordinator {
        PairDeletionCoordinator(
            deletePairs: DeletePairsUseCase(pairRepo: repo, photoLibrary: photoLibrary),
            deleteCombinedExports: DeleteCombinedExportsUseCase(pairRepo: repo, photoLibrary: photoLibrary),
            deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase(pairRepo: repo, photoLibrary: photoLibrary),
            thumbnailCache: thumbnailCache,
        )
    }
}

enum PairDeletionRepoCall: Equatable {
    case fetchAll(tutorialOnly: Bool)
    case fetchOne(id: UUID)
    case fetchMany(ids: [UUID])
    case countCreated
    case add(id: UUID)
    case update(id: UUID)
    case delete(ids: Set<UUID>)
    case deleteCombinedExportRecords(ids: Set<UUID>)
    case combinedExportPhotoIdentifiers
    case allExportPhotoIdentifiers
    case recordExportHistory(id: UUID, kind: ExportHistoryKind)
}

@MainActor
final class PairDeletionRecordingRepo: PhotoPairRepository, @unchecked Sendable {
    private let backing: InMemoryPhotoPairRepo
    private(set) var callLog: [PairDeletionRepoCall] = []

    init(backing: InMemoryPhotoPairRepo) {
        self.backing = backing
    }

    func fetchAll(tutorialOnly: Bool) async throws -> [PhotoPair] {
        callLog.append(.fetchAll(tutorialOnly: tutorialOnly))
        return try await backing.fetchAll(tutorialOnly: tutorialOnly)
    }

    func fetch(id: UUID) async throws -> PhotoPair? {
        callLog.append(.fetchOne(id: id))
        return try await backing.fetch(id: id)
    }

    func fetch(ids: [UUID]) async throws -> [PhotoPair] {
        callLog.append(.fetchMany(ids: ids))
        return try await backing.fetch(ids: ids)
    }

    func countCreated(since date: Date) async throws -> Int {
        callLog.append(.countCreated)
        return try await backing.countCreated(since: date)
    }

    func add(_ pair: PhotoPair) async throws {
        callLog.append(.add(id: pair.id))
        try await backing.add(pair)
    }

    func update(_ pair: PhotoPair) async throws {
        callLog.append(.update(id: pair.id))
        try await backing.update(pair)
    }

    func delete(ids: Set<UUID>) async throws {
        callLog.append(.delete(ids: ids))
        try await backing.delete(ids: ids)
    }

    func deleteCombinedExportRecords(forPairIds ids: Set<UUID>) async throws {
        callLog.append(.deleteCombinedExportRecords(ids: ids))
        try await backing.deleteCombinedExportRecords(forPairIds: ids)
    }

    func combinedExportPhotoIdentifiers(forPairIds ids: Set<UUID>) async throws -> [String] {
        callLog.append(.combinedExportPhotoIdentifiers)
        return try await backing.combinedExportPhotoIdentifiers(forPairIds: ids)
    }

    func allExportPhotoIdentifiers(forPairIds ids: Set<UUID>) async throws -> [String] {
        callLog.append(.allExportPhotoIdentifiers)
        return try await backing.allExportPhotoIdentifiers(forPairIds: ids)
    }

    func recordExportHistory(
        pairId: UUID,
        kind: ExportHistoryKind,
        photoLocalIdentifier: String,
    ) async throws {
        callLog.append(.recordExportHistory(id: pairId, kind: kind))
        try await backing.recordExportHistory(
            pairId: pairId,
            kind: kind,
            photoLocalIdentifier: photoLocalIdentifier,
        )
    }
}
