import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct PhotoPairQueryHostTutorialTests {
    @Test
    func `튜토리얼 active 시 entities 필터링은 튜토리얼 포함`() async throws {
        let container = try makeContainer()
        let repo = SwiftDataPhotoPairRepository(container: container)
        let normal = PhotoPair(id: UUID())
        let tutorial = PhotoPair(id: UUID(), isTutorial: true)
        try await repo.add(normal)
        try await repo.add(tutorial)

        let entities = try fetchAllEntities(container: container)
        let active = TutorialCoordinator(current: .enterSelectionMode)
        let filtered = filterEntities(entities, isTutorialActive: active.isActive)
        let ids = Set(filtered.map(\.id))

        #expect(ids == Set([normal.id, tutorial.id]))
    }

    @Test
    func `튜토리얼 비활성 시 entities 필터링은 일반만`() async throws {
        let container = try makeContainer()
        let repo = SwiftDataPhotoPairRepository(container: container)
        let normal = PhotoPair(id: UUID())
        let tutorial = PhotoPair(id: UUID(), isTutorial: true)
        try await repo.add(normal)
        try await repo.add(tutorial)

        let entities = try fetchAllEntities(container: container)
        let inactive = TutorialCoordinator()
        let filtered = filterEntities(entities, isTutorialActive: inactive.isActive)
        let ids = filtered.map(\.id)

        #expect(ids == [normal.id])
    }

    @Test
    func `done 상태는 비활성으로 간주되어 일반만 노출`() async throws {
        let container = try makeContainer()
        let repo = SwiftDataPhotoPairRepository(container: container)
        let normal = PhotoPair(id: UUID())
        let tutorial = PhotoPair(id: UUID(), isTutorial: true)
        try await repo.add(normal)
        try await repo.add(tutorial)

        let entities = try fetchAllEntities(container: container)
        let done = TutorialCoordinator(current: .done)
        let filtered = filterEntities(entities, isTutorialActive: done.isActive)

        #expect(filtered.map(\.id) == [normal.id])
    }

    private func filterEntities(
        _ entities: [PhotoPairEntity],
        isTutorialActive: Bool,
    ) -> [PhotoPairEntity] {
        isTutorialActive ? entities : entities.filter { !$0.isTutorial }
    }

    private func fetchAllEntities(container: ModelContainer) throws -> [PhotoPairEntity] {
        let descriptor = FetchDescriptor<PhotoPairEntity>()
        return try container.mainContext.fetch(descriptor)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
