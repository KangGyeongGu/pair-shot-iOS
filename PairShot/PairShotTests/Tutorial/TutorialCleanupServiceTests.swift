import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct TutorialCleanupServiceTests {
    @Test
    func `deleteAllTutorialPairs 호출 후 일반 페어만 남는다`() async throws {
        let container = try makeContainer()
        let pairRepo = SwiftDataPhotoPairRepository(container: container)
        let normalA = PhotoPair(id: UUID())
        let normalB = PhotoPair(id: UUID())
        let tutorialA = PhotoPair(id: UUID(), isTutorial: true)
        let tutorialB = PhotoPair(id: UUID(), isTutorial: true)
        try await pairRepo.add(normalA)
        try await pairRepo.add(normalB)
        try await pairRepo.add(tutorialA)
        try await pairRepo.add(tutorialB)

        let service = TutorialCleanupService(
            container: container,
            photoLibrary: PhotoLibraryService(),
        )
        try await service.deleteAllTutorialPairs()

        let remaining = try await pairRepo.fetchAll()
        let remainingIds = Set(remaining.map(\.id))
        #expect(remainingIds == Set([normalA.id, normalB.id]))

        let allEntities = try fetchAllRaw(container: container)
        let allIds = Set(allEntities.map(\.id))
        #expect(allIds == Set([normalA.id, normalB.id]))
    }

    @Test
    func `튜토리얼 페어가 없을 때 deleteAllTutorialPairs 는 noop`() async throws {
        let container = try makeContainer()
        let pairRepo = SwiftDataPhotoPairRepository(container: container)
        let normal = PhotoPair(id: UUID())
        try await pairRepo.add(normal)

        let service = TutorialCleanupService(
            container: container,
            photoLibrary: PhotoLibraryService(),
        )
        try await service.deleteAllTutorialPairs()

        let remaining = try await pairRepo.fetchAll()
        #expect(remaining.map(\.id) == [normal.id])
    }

    @Test
    func `deleteAllTutorialPairs 는 일반 페어가 0개여도 동작한다`() async throws {
        let container = try makeContainer()
        let tutorial = PhotoPair(id: UUID(), isTutorial: true)
        let pairRepo = SwiftDataPhotoPairRepository(container: container)
        try await pairRepo.add(tutorial)

        let service = TutorialCleanupService(
            container: container,
            photoLibrary: PhotoLibraryService(),
        )
        try await service.deleteAllTutorialPairs()

        let remaining = try await pairRepo.fetchAll()
        #expect(remaining.isEmpty)
        let allEntities = try fetchAllRaw(container: container)
        #expect(allEntities.isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func fetchAllRaw(container: ModelContainer) throws -> [PhotoPairEntity] {
        let descriptor = FetchDescriptor<PhotoPairEntity>()
        return try container.mainContext.fetch(descriptor)
    }
}
