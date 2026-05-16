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

    private func fetchAlbumEntity(id: UUID) throws -> AlbumEntity? {
        let descriptor = FetchDescriptor<AlbumEntity>(
            predicate: #Predicate { $0.id == id },
        )
        return try context.fetch(descriptor).first
    }

    private func fetchPair(id: UUID) throws -> PhotoPairEntity? {
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { $0.id == id },
        )
        return try context.fetch(descriptor).first
    }

    private func makeEntity(from domain: Album) -> AlbumEntity {
        AlbumEntity(
            name: domain.name,
            id: domain.id,
            latitude: domain.latitude,
            longitude: domain.longitude,
            locationLabel: domain.locationLabel,
            createdAt: domain.createdAt,
        )
    }

    private func applyDomainFields(_ domain: Album, to entity: AlbumEntity) {
        entity.name = domain.name
        entity.latitude = domain.latitude
        entity.longitude = domain.longitude
        entity.locationLabel = domain.locationLabel
    }
}
