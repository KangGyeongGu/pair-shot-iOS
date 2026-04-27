import Foundation

protocol PhotoPairRepository: Sendable {
    func observeAll() -> AsyncStream<[PhotoPair]>
    func observe(albumId: UUID?) -> AsyncStream<[PhotoPair]>
    func fetchAll() async throws -> [PhotoPair]
    func fetch(id: UUID) async throws -> PhotoPair?
    func add(_ pair: PhotoPair) async throws
    func update(_ pair: PhotoPair) async throws
    func delete(id: UUID) async throws
    func delete(ids: Set<UUID>) async throws
    func nextSequenceNumber() async throws -> Int
}
