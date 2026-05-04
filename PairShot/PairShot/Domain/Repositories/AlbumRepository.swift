import Foundation

protocol AlbumRepository: Sendable {
    func fetchAll() async throws -> [Album]
    func fetch(id: UUID) async throws -> Album?
    func add(_ album: Album) async throws
    func update(_ album: Album) async throws
    func delete(id: UUID) async throws
    func addPair(pairId: UUID, toAlbum albumId: UUID) async throws
    func removePair(pairId: UUID, fromAlbum albumId: UUID) async throws
}
