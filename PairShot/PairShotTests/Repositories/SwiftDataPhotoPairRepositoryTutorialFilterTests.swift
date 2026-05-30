import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct SwiftDataPhotoPairRepositoryTutorialFilterTests {
    @Test
    func `fetchAll 기본은 isTutorial true 인 페어를 제외한다`() async throws {
        let repository = try makeRepository()
        let normal = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 100))
        let tutorial = PhotoPair(
            id: UUID(),
            createdAt: Date(timeIntervalSinceReferenceDate: 200),
            isTutorial: true,
        )
        try await repository.add(normal)
        try await repository.add(tutorial)

        let result = try await repository.fetchAll(tutorialOnly: false)
        #expect(result.map(\.id) == [normal.id])
    }

    @Test
    func `fetchAll includeTutorial true 면 튜토리얼 페어만 반환한다`() async throws {
        let repository = try makeRepository()
        let normal = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 100))
        let tutorial = PhotoPair(
            id: UUID(),
            createdAt: Date(timeIntervalSinceReferenceDate: 200),
            isTutorial: true,
        )
        try await repository.add(normal)
        try await repository.add(tutorial)

        let result = try await repository.fetchAll(tutorialOnly: true)
        #expect(result.map(\.id) == [tutorial.id])
    }

    @Test
    func `fetch by id 는 튜토리얼 페어도 반환한다`() async throws {
        let repository = try makeRepository()
        let tutorial = PhotoPair(id: UUID(), isTutorial: true)
        try await repository.add(tutorial)

        let result = try await repository.fetch(id: tutorial.id)
        #expect(result?.id == tutorial.id)
        #expect(result?.isTutorial == true)
    }

    @Test
    func `fetch by ids 는 튜토리얼 id 도 결과에 포함한다`() async throws {
        let repository = try makeRepository()
        let normal = PhotoPair(id: UUID())
        let tutorial = PhotoPair(id: UUID(), isTutorial: true)
        try await repository.add(normal)
        try await repository.add(tutorial)

        let result = try await repository.fetch(ids: [normal.id, tutorial.id])
        #expect(Set(result.map(\.id)) == Set([normal.id, tutorial.id]))
    }

    @Test
    func `countCreated 는 튜토리얼 페어를 카운트하지 않는다`() async throws {
        let repository = try makeRepository()
        let cutoff = Date(timeIntervalSinceReferenceDate: 0)
        let normalA = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 100))
        let normalB = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 200))
        let tutorial = PhotoPair(
            id: UUID(),
            createdAt: Date(timeIntervalSinceReferenceDate: 300),
            isTutorial: true,
        )
        try await repository.add(normalA)
        try await repository.add(normalB)
        try await repository.add(tutorial)

        let count = try await repository.countCreated(since: cutoff)
        #expect(count == 2)
    }

    @Test
    func `add 시 isTutorial 값이 영속화된다`() async throws {
        let repository = try makeRepository()
        let normal = PhotoPair(id: UUID(), isTutorial: false)
        let tutorial = PhotoPair(id: UUID(), isTutorial: true)
        try await repository.add(normal)
        try await repository.add(tutorial)

        let normalFetched = try await repository.fetch(id: normal.id)
        #expect(normalFetched?.isTutorial == false)
        let tutorialFetched = try await repository.fetch(id: tutorial.id)
        #expect(tutorialFetched?.isTutorial == true)
    }

    private func makeRepository() throws -> SwiftDataPhotoPairRepository {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SwiftDataPhotoPairRepository(container: container)
    }
}
