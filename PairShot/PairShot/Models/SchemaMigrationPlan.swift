import Foundation
import SwiftData

enum PairShotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2]
    }

    static let v1ToV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            try V1ToV2Migrator.willMigrate(context: context)
        },
        didMigrate: { context in
            try V1ToV2Migrator.didMigrate(context: context)
        }
    )
}

enum V1ToV2Migrator {
    struct LegacySnapshot: Equatable {
        let projectId: UUID
        let projectTitle: String
        let projectLatitude: Double?
        let projectLongitude: Double?
        let projectLocationLabel: String?
        let projectCreatedAt: Date
        let projectUpdatedAt: Date
        let pairs: [PairSnapshot]
    }

    struct PairSnapshot: Equatable {
        let pairId: UUID
        let beforePath: String
        let afterPath: String?
        let combinedPath: String?
        let beforeCapturedAt: Date
        let afterCapturedAt: Date?
        let beforeZoomFactor: Double
        let beforeLensIdentifier: String?
    }

    nonisolated(unsafe) static var capturedSnapshots: [LegacySnapshot] = []

    static func willMigrate(context: ModelContext) throws {
        let projects = try context.fetch(FetchDescriptor<SchemaV1.LegacyProject>())
        capturedSnapshots = projects.map { project in
            LegacySnapshot(
                projectId: project.id,
                projectTitle: project.title,
                projectLatitude: project.latitude,
                projectLongitude: project.longitude,
                projectLocationLabel: project.locationLabel,
                projectCreatedAt: project.createdAt,
                projectUpdatedAt: project.updatedAt,
                pairs: project.pairs.map { pair in
                    PairSnapshot(
                        pairId: pair.id,
                        beforePath: pair.beforePath,
                        afterPath: pair.afterPath,
                        combinedPath: pair.combinedPath,
                        beforeCapturedAt: pair.beforeCapturedAt,
                        afterCapturedAt: pair.afterCapturedAt,
                        beforeZoomFactor: pair.beforeZoomFactor,
                        beforeLensIdentifier: pair.beforeLensIdentifier
                    )
                }
            )
        }
        for project in projects {
            context.delete(project)
        }
        try context.save()
    }

    static func didMigrate(context: ModelContext) throws {
        let snapshots = capturedSnapshots
        capturedSnapshots = []
        for snapshot in snapshots {
            let album = Album(
                name: snapshot.projectTitle,
                latitude: snapshot.projectLatitude,
                longitude: snapshot.projectLongitude,
                locationLabel: snapshot.projectLocationLabel,
                createdAt: snapshot.projectCreatedAt
            )
            album.updatedAt = snapshot.projectUpdatedAt
            context.insert(album)

            for pairSnapshot in snapshot.pairs {
                let pair = makePair(from: pairSnapshot, parent: snapshot)
                context.insert(pair)
                pair.albums.append(album)
            }
        }
        try context.save()
    }

    private static func makePair(from snapshot: PairSnapshot, parent: LegacySnapshot) -> PhotoPair {
        let camera = CameraSettings(
            zoomFactor: snapshot.beforeZoomFactor,
            lensPosition: lensPosition(for: snapshot.beforeLensIdentifier),
            flashMode: .off,
            useGrid: false,
            useNightMode: false
        )
        let pair = PhotoPair(
            beforeFileName: extractFileName(snapshot.beforePath),
            cameraSettings: camera,
            latitude: parent.projectLatitude,
            longitude: parent.projectLongitude,
            locationLabel: parent.projectLocationLabel,
            capturedAt: snapshot.beforeCapturedAt
        )
        pair.afterFileName = snapshot.afterPath.map(extractFileName)
        pair.afterCapturedAt = snapshot.afterCapturedAt
        pair.combinedFileName = snapshot.combinedPath.map(extractFileName)
        pair.updatedAt = snapshot.afterCapturedAt ?? snapshot.beforeCapturedAt
        return pair
    }

    static func extractFileName(_ relativePath: String) -> String {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return (trimmed as NSString).lastPathComponent
    }

    static func lensPosition(for identifier: String?) -> LensPosition {
        guard let identifier else { return .backWide }
        let lower = identifier.lowercased()
        if lower.contains("ultra") { return .backUltraWide }
        if lower.contains("tele") { return .backTele }
        if lower.contains("front") { return .front }
        if lower.contains("triple") { return .backTriple }
        if lower.contains("dual") { return .backDualWide }
        return .backWide
    }
}
