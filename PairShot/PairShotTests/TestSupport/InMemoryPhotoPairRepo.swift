import Foundation
@testable import PairShot

@MainActor
final class InMemoryPhotoPairRepo: PhotoPairRepository, @unchecked Sendable {
    private var pairs: [UUID: PhotoPair] = [:]
    private var insertionOrder: [UUID] = []
    private var combinedExportRecords: [UUID: [String]] = [:]
    private var allExportRecords: [UUID: [String]] = [:]

    init(pairs: [PhotoPair] = []) {
        for pair in pairs {
            self.pairs[pair.id] = pair
            insertionOrder.append(pair.id)
        }
    }

    func fetchAll(tutorialOnly: Bool) async throws -> [PhotoPair] {
        insertionOrder.compactMap { id in
            guard let pair = pairs[id] else { return nil }
            if tutorialOnly { return pair.isTutorial ? pair : nil }
            return pair
        }
    }

    func fetch(id: UUID) async throws -> PhotoPair? {
        pairs[id]
    }

    func fetch(ids: [UUID]) async throws -> [PhotoPair] {
        ids.compactMap { pairs[$0] }
    }

    func countCreated(since date: Date) async throws -> Int {
        pairs.values.count(where: { $0.createdAt >= date })
    }

    func add(_ pair: PhotoPair) async throws {
        if pairs[pair.id] == nil {
            insertionOrder.append(pair.id)
        }
        pairs[pair.id] = pair
    }

    func update(_ pair: PhotoPair) async throws {
        guard pairs[pair.id] != nil else { return }
        pairs[pair.id] = pair
    }

    func delete(ids: Set<UUID>) async throws {
        for id in ids {
            pairs.removeValue(forKey: id)
            combinedExportRecords.removeValue(forKey: id)
            allExportRecords.removeValue(forKey: id)
        }
        insertionOrder.removeAll { ids.contains($0) }
    }

    func deleteCombinedExportRecords(forPairIds ids: Set<UUID>) async throws {
        for id in ids {
            combinedExportRecords.removeValue(forKey: id)
        }
    }

    func combinedExportPhotoIdentifiers(forPairIds ids: Set<UUID>) async throws -> [String] {
        ids.flatMap { combinedExportRecords[$0] ?? [] }
    }

    func allExportPhotoIdentifiers(forPairIds ids: Set<UUID>) async throws -> [String] {
        ids.flatMap { allExportRecords[$0] ?? [] }
    }

    func recordExportHistory(
        pairId: UUID,
        kind: ExportHistoryKind,
        photoLocalIdentifier: String,
    ) async throws {
        allExportRecords[pairId, default: []].append(photoLocalIdentifier)
        if kind == .combined {
            combinedExportRecords[pairId, default: []].append(photoLocalIdentifier)
        }
    }
}
