import Foundation
@testable import PairShot
import Testing

@MainActor
struct DeleteAfterPhotoUseCaseTests {
    @Test
    func `Before·After·Combined 가 모두 있는 페어 → After·합성 자산만 정리, Before 보존, status 가 scheduled 로 전이`() async throws {
        let repo = InMemoryPhotoPairRepo()
        let pair = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-asset",
            afterPhotoLocalIdentifier: "after-asset",
            afterCapturedAt: .now,
            hasCombinedExport: true,
        )
        try await repo.add(pair)
        try await repo.recordExportHistory(
            pairId: pair.id,
            kind: .combined,
            photoLocalIdentifier: "combined-asset-1",
        )
        try await repo.recordExportHistory(
            pairId: pair.id,
            kind: .combined,
            photoLocalIdentifier: "combined-asset-2",
        )
        let useCase = DeleteAfterPhotoUseCase(pairRepo: repo, photoLibrary: PhotoLibraryService())

        let updated = try await useCase(pairId: pair.id)

        let refetched = try await repo.fetch(id: pair.id)
        #expect(refetched?.beforePhotoLocalIdentifier == "before-asset")
        #expect(refetched?.afterPhotoLocalIdentifier == nil)
        #expect(refetched?.afterCapturedAt == nil)
        #expect(refetched?.hasCombinedExport == false)
        #expect(refetched?.status == .scheduled)
        #expect(updated?.afterPhotoLocalIdentifier == nil)
        let combinedRemaining = try await repo.combinedExportPhotoIdentifiers(forPairIds: [pair.id])
        #expect(combinedRemaining.isEmpty)
    }

    @Test
    func `Combined 자산이 없는 페어 → After 만 정리되고 pair 업데이트 정상 (combined 정리 단계 안전 no-op)`() async throws {
        let repo = InMemoryPhotoPairRepo()
        let pair = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-asset",
            afterPhotoLocalIdentifier: "after-asset",
            afterCapturedAt: .now,
            hasCombinedExport: false,
        )
        try await repo.add(pair)
        let useCase = DeleteAfterPhotoUseCase(pairRepo: repo, photoLibrary: PhotoLibraryService())

        _ = try await useCase(pairId: pair.id)

        let refetched = try await repo.fetch(id: pair.id)
        #expect(refetched?.afterPhotoLocalIdentifier == nil)
        #expect(refetched?.beforePhotoLocalIdentifier == "before-asset")
        #expect(refetched?.status == .scheduled)
    }

    @Test
    func `존재하지 않는 pairId → nil 반환, throw 안 함 (race 상황 안전)`() async throws {
        let repo = InMemoryPhotoPairRepo()
        let useCase = DeleteAfterPhotoUseCase(pairRepo: repo, photoLibrary: PhotoLibraryService())

        let result = try await useCase(pairId: UUID())

        #expect(result == nil)
    }

    @Test
    func `이미 After 가 없는 페어 (scheduled) → no-op 으로 Before 손상 없이 통과`() async throws {
        let repo = InMemoryPhotoPairRepo()
        let pair = FixturePhotoPair.makeBeforeOnly(
            beforePhotoLocalIdentifier: "before-asset",
        )
        try await repo.add(pair)
        let useCase = DeleteAfterPhotoUseCase(pairRepo: repo, photoLibrary: PhotoLibraryService())

        _ = try await useCase(pairId: pair.id)

        let refetched = try await repo.fetch(id: pair.id)
        #expect(refetched?.beforePhotoLocalIdentifier == "before-asset")
        #expect(refetched?.afterPhotoLocalIdentifier == nil)
        #expect(refetched?.status == .scheduled)
    }
}
