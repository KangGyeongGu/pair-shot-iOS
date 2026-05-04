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

    func deleteCombinedExportRecords(forPairIds ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<PhotoPair>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let pairs = try context.fetch(descriptor)
        var didDelete = false
        for pair in pairs {
            let combined = pair.exportHistory.filter { $0.kind == .combined }
            for record in combined {
                context.delete(record)
                didDelete = true
            }
        }
        if didDelete {
            try context.save()
        }
    }

    private func fetchAllSync() throws -> [PhotoPair] {
        let descriptor = FetchDescriptor<PhotoPair>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
