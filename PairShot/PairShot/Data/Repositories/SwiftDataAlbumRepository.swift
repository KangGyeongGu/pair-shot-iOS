import Foundation
import SwiftData

@MainActor
final class SwiftDataAlbumRepository: AlbumRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    init(container: ModelContainer) {
        self.container = container
    }

    nonisolated func observeAll() -> AsyncStream<[Album]> {
        AsyncStream { continuation in
            Task { @MainActor in
                let snapshot = (try? self.fetchAllSync()) ?? []
                continuation.yield(snapshot)
                continuation.finish()
            }
        }
    }

    func fetchAll() async throws -> [Album] {
        try fetchAllSync()
    }

    func fetch(id: UUID) async throws -> Album? {
        try fetchAlbum(id: id)
    }

    func add(_ album: Album) async throws {
        context.insert(album)
        try context.save()
    }

    func update(_ album: Album) async throws {
        album.updatedAt = .now
        try context.save()
    }

    func delete(id: UUID) async throws {
        guard let album = try fetchAlbum(id: id) else { return }
        context.delete(album)
        try context.save()
    }

    func addPair(pairId: UUID, toAlbum albumId: UUID) async throws {
        guard
            let album = try fetchAlbum(id: albumId),
            let pair = try fetchPair(id: pairId)
        else { return }
        if !pair.albums.contains(where: { $0.id == albumId }) {
            pair.albums.append(album)
        }
        album.updatedAt = .now
        pair.updatedAt = .now
        try context.save()
    }

    func removePair(pairId: UUID, fromAlbum albumId: UUID) async throws {
        guard
            let album = try fetchAlbum(id: albumId),
            let pair = try fetchPair(id: pairId)
        else { return }
        pair.albums.removeAll { $0.id == albumId }
        album.updatedAt = .now
        pair.updatedAt = .now
        try context.save()
    }

    private func fetchAllSync() throws -> [Album] {
        let descriptor = FetchDescriptor<Album>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchAlbum(id: UUID) throws -> Album? {
        let descriptor = FetchDescriptor<Album>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private func fetchPair(id: UUID) throws -> PhotoPair? {
        let descriptor = FetchDescriptor<PhotoPair>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    deinit {}
}
