import Foundation

protocol PhotoPairRepository: Sendable {
    func fetchAll() async throws -> [PhotoPair]
    func fetch(id: UUID) async throws -> PhotoPair?
    func add(_ pair: PhotoPair) async throws
    func update(_ pair: PhotoPair) async throws
    func delete(id: UUID) async throws
    func delete(ids: Set<UUID>) async throws
    func deleteCombinedExportRecords(forPairIds ids: Set<UUID>) async throws
}
