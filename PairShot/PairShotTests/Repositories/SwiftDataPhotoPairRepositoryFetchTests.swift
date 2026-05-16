import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct SwiftDataPhotoPairRepositoryFetchTests {
    @Test
    func `fetch by ids preserves input order`() async throws {
        let repository = try makeRepository()
        let pairA = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 100))
        let pairB = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 200))
        let pairC = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 300))
        try await repository.add(pairA)
        try await repository.add(pairB)
        try await repository.add(pairC)

        let result = try await repository.fetch(ids: [pairA.id, pairB.id, pairC.id])
        #expect(result.map(\.id) == [pairA.id, pairB.id, pairC.id])

        let reversed = try await repository.fetch(ids: [pairC.id, pairA.id, pairB.id])
        #expect(reversed.map(\.id) == [pairC.id, pairA.id, pairB.id])
    }

    @Test
    func `fetch by ids omits missing entries while preserving order`() async throws {
        let repository = try makeRepository()
        let pairA = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 100))
        let pairC = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 300))
        try await repository.add(pairA)
        try await repository.add(pairC)
        let missing = UUID()

        let result = try await repository.fetch(ids: [pairA.id, missing, pairC.id])
        #expect(result.map(\.id) == [pairA.id, pairC.id])
    }

    @Test
    func `fetch by empty ids returns empty array`() async throws {
        let repository = try makeRepository()
        try await repository.add(PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 100)))

        let result = try await repository.fetch(ids: [])
        #expect(result.isEmpty)
    }

    @Test
    func `fetch by ids with duplicates preserves duplicates in output`() async throws {
        let repository = try makeRepository()
        let pairA = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 100))
        let pairB = PhotoPair(id: UUID(), createdAt: Date(timeIntervalSinceReferenceDate: 200))
        try await repository.add(pairA)
        try await repository.add(pairB)

        let result = try await repository.fetch(ids: [pairA.id, pairB.id, pairA.id])
        #expect(result.map(\.id) == [pairA.id, pairB.id, pairA.id])
    }

    private func makeRepository() throws -> SwiftDataPhotoPairRepository {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SwiftDataPhotoPairRepository(container: container)
    }
}
