import Foundation

protocol PhotoPairRepository: Sendable {
    func fetchAll(tutorialOnly: Bool) async throws -> [PhotoPair]
    func fetch(id: UUID) async throws -> PhotoPair?
    func fetch(ids: [UUID]) async throws -> [PhotoPair]
    func countCreated(since date: Date) async throws -> Int
    func add(_ pair: PhotoPair) async throws
    func update(_ pair: PhotoPair) async throws
    func delete(ids: Set<UUID>) async throws
    func deleteCombinedExportRecords(forPairIds ids: Set<UUID>) async throws
    func combinedExportPhotoIdentifiers(forPairIds ids: Set<UUID>) async throws -> [String]
    func allExportPhotoIdentifiers(forPairIds ids: Set<UUID>) async throws -> [String]
    func recordExportHistory(pairId: UUID, kind: ExportHistoryKind, photoLocalIdentifier: String) async throws
}

extension PhotoPairRepository {
    func fetchAll() async throws -> [PhotoPair] {
        try await fetchAll(tutorialOnly: false)
    }
}
