import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct PhotoPairCountTests {
    private static let frozenNow = Date(timeIntervalSinceReferenceDate: 700_000_000)
    private static let calendar = Calendar(identifier: .gregorian)

    @Test("countCreated returns 0 on empty store")
    func countCreatedReturnsZeroWhenEmpty() async throws {
        let repository = try makeRepository()
        let result = try await repository.countCreated(since: .distantPast)
        #expect(result == 0)
    }

    @Test("countCreated since today midnight excludes earlier days")
    func countCreatedSinceFiltersByDate() async throws {
        let repository = try makeRepository()
        let now = Self.frozenNow
        let todayStart = Self.calendar.startOfDay(for: now)
        let yesterday = try #require(Self.calendar.date(byAdding: .day, value: -1, to: now))
        let twoDaysAgo = try #require(Self.calendar.date(byAdding: .day, value: -2, to: now))

        try await repository.add(PhotoPair(createdAt: now))
        try await repository.add(PhotoPair(createdAt: now))
        try await repository.add(PhotoPair(createdAt: now))
        try await repository.add(PhotoPair(createdAt: yesterday))
        try await repository.add(PhotoPair(createdAt: twoDaysAgo))

        let todayCount = try await repository.countCreated(since: todayStart)
        #expect(todayCount == 3)

        let allCount = try await repository.countCreated(since: .distantPast)
        #expect(allCount == 5)
    }

    @Test("countCreated since future date returns 0")
    func countCreatedSinceFutureReturnsZero() async throws {
        let repository = try makeRepository()
        try await repository.add(PhotoPair(createdAt: Self.frozenNow))
        let future = try #require(Self.calendar.date(byAdding: .day, value: 1, to: Self.frozenNow))
        let result = try await repository.countCreated(since: future)
        #expect(result == 0)
    }

    private func makeRepository() throws -> SwiftDataPhotoPairRepository {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SwiftDataPhotoPairRepository(container: container)
    }
}
