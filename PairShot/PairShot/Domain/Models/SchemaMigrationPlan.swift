import Foundation
import SwiftData

nonisolated enum PairShotMigrationPlan: SchemaMigrationPlan {
    nonisolated static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    nonisolated static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3]
    }

    nonisolated static let v1ToV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            try V1ToV2Migrator.willMigrate(context: context)
        },
        didMigrate: { context in
            try V1ToV2Migrator.didMigrate(context: context)
        }
    )

    nonisolated static let v2ToV3 = MigrationStage.custom(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self,
        willMigrate: nil,
        didMigrate: { context in
            try V2ToV3Migrator.didMigrate(context: context)
        }
    )
}

nonisolated enum V2ToV3Migrator {
    nonisolated static func didMigrate(context: ModelContext) throws {
        let coupons = try context.fetch(FetchDescriptor<Coupon>())
        var changed = false
        for coupon in coupons {
            if coupon.kindRawString.isEmpty {
                coupon.kindRawString = "\(CouponKind.timedPrefix)\(coupon.durationDays)"
                changed = true
            }
            if coupon.payloadVersion == 0 {
                coupon.payloadVersion = CouponPayload.currentVersion
                changed = true
            }
            if coupon.issuedAt == Date(timeIntervalSince1970: 0) {
                coupon.issuedAt = coupon.activatedAt
                changed = true
            }
        }
        if changed {
            try context.save()
        }
    }
}

nonisolated enum V1ToV2Migrator {
    nonisolated struct LegacySnapshot: Equatable {
        let projectId: UUID
        let projectTitle: String
        let projectLatitude: Double?
        let projectLongitude: Double?
        let projectLocationLabel: String?
        let projectCreatedAt: Date
        let projectUpdatedAt: Date
        let pairs: [PairSnapshot]
    }

    nonisolated struct PairSnapshot: Equatable {
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

    nonisolated static func willMigrate(context: ModelContext) throws {
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

    nonisolated static func didMigrate(context: ModelContext) throws {
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

    private nonisolated static func makePair(from snapshot: PairSnapshot, parent: LegacySnapshot) -> PhotoPair {
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

    nonisolated static func extractFileName(_ relativePath: String) -> String {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return (trimmed as NSString).lastPathComponent
    }

    nonisolated static func lensPosition(for identifier: String?) -> LensPosition {
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
