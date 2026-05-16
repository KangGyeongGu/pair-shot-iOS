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
        try fetchAllSync().map { $0.toDomain() }
    }

    func fetch(id: UUID) async throws -> PhotoPair? {
        try fetchEntity(id: id)?.toDomain()
    }

    func countCreated(since date: Date) async throws -> Int {
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { $0.createdAt >= date },
        )
        return try context.fetchCount(descriptor)
    }

    func add(_ pair: PhotoPair) async throws {
        let entity = makeEntity(from: pair)
        context.insert(entity)
        try context.save()
    }

    func update(_ pair: PhotoPair) async throws {
        guard let entity = try fetchEntity(id: pair.id) else { return }
        applyDomainFields(pair, to: entity)
        entity.updatedAt = .now
        try context.save()
    }

    func delete(ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { ids.contains($0.id) },
        )
        let matches = try context.fetch(descriptor)
        for entity in matches {
            context.delete(entity)
        }
        try context.save()
    }

    func deleteCombinedExportRecords(forPairIds ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { ids.contains($0.id) },
        )
        let entities = try context.fetch(descriptor)
        var didDelete = false
        for entity in entities {
            let combined = entity.exportHistory.filter { $0.kind == .combined }
            for record in combined {
                context.delete(record)
                didDelete = true
            }
        }
        if didDelete {
            try context.save()
        }
    }

    func combinedExportPhotoIdentifiers(forPairIds ids: Set<UUID>) async throws -> [String] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { ids.contains($0.id) },
        )
        let entities = try context.fetch(descriptor)
        var collected: [String] = []
        for entity in entities {
            for record in entity.exportHistory where record.kind == .combined {
                if !record.photoLocalIdentifier.isEmpty {
                    collected.append(record.photoLocalIdentifier)
                }
            }
        }
        return collected
    }

    func allExportPhotoIdentifiers(forPairIds ids: Set<UUID>) async throws -> [String] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { ids.contains($0.id) },
        )
        let entities = try context.fetch(descriptor)
        var collected: [String] = []
        for entity in entities {
            for record in entity.exportHistory where !record.photoLocalIdentifier.isEmpty {
                collected.append(record.photoLocalIdentifier)
            }
        }
        return collected
    }

    func recordExportHistory(
        pairId: UUID,
        kind: ExportHistoryKind,
        photoLocalIdentifier: String,
    ) async throws {
        let pairEntity = try fetchEntity(id: pairId)
        let record = ExportHistoryEntity(
            kind: kind,
            photoLocalIdentifier: photoLocalIdentifier,
            pair: pairEntity,
        )
        context.insert(record)
        try context.save()
    }

    private func fetchAllSync() throws -> [PhotoPairEntity] {
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)],
        )
        return try context.fetch(descriptor)
    }

    private func fetchEntity(id: UUID) throws -> PhotoPairEntity? {
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { $0.id == id },
        )
        return try context.fetch(descriptor).first
    }

    private func makeEntity(from domain: PhotoPair) -> PhotoPairEntity {
        PhotoPairEntity(
            id: domain.id,
            beforePhotoLocalIdentifier: domain.beforePhotoLocalIdentifier,
            afterPhotoLocalIdentifier: domain.afterPhotoLocalIdentifier,
            beforeZoomFactor: domain.beforeZoomFactor,
            beforeLensIdentifier: domain.beforeLensIdentifier,
            cameraSettings: domain.cameraSettings,
            latitude: domain.latitude,
            longitude: domain.longitude,
            locationLabel: domain.locationLabel,
            capturedAt: domain.createdAt,
            updatedAt: domain.updatedAt,
            afterCapturedAt: domain.afterCapturedAt,
        )
    }

    private func applyDomainFields(_ domain: PhotoPair, to entity: PhotoPairEntity) {
        entity.beforePhotoLocalIdentifier = domain.beforePhotoLocalIdentifier
        entity.afterPhotoLocalIdentifier = domain.afterPhotoLocalIdentifier
        entity.beforeZoomFactor = domain.beforeZoomFactor
        entity.beforeLensIdentifier = domain.beforeLensIdentifier
        entity.afterCapturedAt = domain.afterCapturedAt
        entity.latitude = domain.latitude
        entity.longitude = domain.longitude
        entity.locationLabel = domain.locationLabel
        entity.cameraSettings = domain.cameraSettings
    }
}
