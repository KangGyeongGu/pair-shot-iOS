import Foundation
@preconcurrency import SwiftData

@MainActor
final class SwiftDataPhotoPairRepository: PhotoPairRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    init(container: ModelContainer) {
        self.container = container
    }

    nonisolated func observeAll() -> AsyncStream<[PhotoPair]> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    nonisolated func observe(albumId _: UUID?) -> AsyncStream<[PhotoPair]> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func fetchAll() async throws -> [PhotoPair] {
        try fetchAllSync()
    }

    func fetch(id: UUID) async throws -> PhotoPair? {
        let descriptor = FetchDescriptor<PhotoPair>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    func add(_ pair: PhotoPair) async throws {
        context.insert(pair)
        try context.save()
    }

    func update(_ pair: PhotoPair) async throws {
        pair.updatedAt = .now
        try context.save()
    }

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<PhotoPair>(
            predicate: #Predicate { $0.id == id }
        )
        guard let pair = try context.fetch(descriptor).first else { return }
        context.delete(pair)
        try context.save()
    }

    func delete(ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<PhotoPair>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let matches = try context.fetch(descriptor)
        for pair in matches {
            context.delete(pair)
        }
        try context.save()
    }

    func nextSequenceNumber() async throws -> Int {
        let all = try fetchAllSync()
        return all.count + 1
    }

    private func fetchAllSync() throws -> [PhotoPair] {
        let descriptor = FetchDescriptor<PhotoPair>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchSync(albumId: UUID?) throws -> [PhotoPair] {
        let all = try fetchAllSync()
        guard let albumId else { return all }
        return all.filter { pair in
            pair.albums.contains { $0.id == albumId }
        }
    }

    deinit {}
}
