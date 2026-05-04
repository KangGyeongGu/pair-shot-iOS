import Foundation
@preconcurrency import SwiftData

@MainActor
final class SwiftDataAlbumRepository: AlbumRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAll() async throws -> [Album] {
        try fetchAllSync().map(toDomain)
    }

    func fetch(id: UUID) async throws -> Album? {
        try fetchAlbumEntity(id: id).map(toDomain)
    }

    func add(_ album: Album) async throws {
        let entity = makeEntity(from: album)
        context.insert(entity)
        try context.save()
    }

    func update(_ album: Album) async throws {
        guard let entity = try fetchAlbumEntity(id: album.id) else { return }
        applyDomainFields(album, to: entity)
        entity.updatedAt = .now
        try context.save()
    }

    func delete(id: UUID) async throws {
        guard let entity = try fetchAlbumEntity(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    func addPair(pairId: UUID, toAlbum albumId: UUID) async throws {
        guard
            let entity = try fetchAlbumEntity(id: albumId),
            let pair = try fetchPair(id: pairId)
        else { return }
        if !pair.albums.contains(where: { $0.id == albumId }) {
            pair.albums.append(entity)
        }
        entity.updatedAt = .now
        pair.updatedAt = .now
        try context.save()
    }

    func removePair(pairId: UUID, fromAlbum albumId: UUID) async throws {
        guard
            let entity = try fetchAlbumEntity(id: albumId),
            let pair = try fetchPair(id: pairId)
        else { return }
        pair.albums.removeAll { $0.id == albumId }
        entity.updatedAt = .now
        pair.updatedAt = .now
        try context.save()
    }

    private func fetchAllSync() throws -> [AlbumEntity] {
        let descriptor = FetchDescriptor<AlbumEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchAlbumEntity(id: UUID) throws -> AlbumEntity? {
        let descriptor = FetchDescriptor<AlbumEntity>(
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

    private func toDomain(_ entity: AlbumEntity) -> Album {
        Album(
            id: entity.id,
            name: entity.name,
            latitude: entity.latitude,
            longitude: entity.longitude,
            locationLabel: entity.locationLabel,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            pairIds: entity.pairs.map(\.id)
        )
    }

    private func makeEntity(from domain: Album) -> AlbumEntity {
        AlbumEntity(
            id: domain.id,
            name: domain.name,
            latitude: domain.latitude,
            longitude: domain.longitude,
            locationLabel: domain.locationLabel,
            createdAt: domain.createdAt
        )
    }

    private func applyDomainFields(_ domain: Album, to entity: AlbumEntity) {
        entity.name = domain.name
        entity.latitude = domain.latitude
        entity.longitude = domain.longitude
        entity.locationLabel = domain.locationLabel
    }
}
