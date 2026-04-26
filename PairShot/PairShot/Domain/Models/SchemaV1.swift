import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static let versionIdentifier: Schema.Version = .init(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [LegacyProject.self, LegacyPhotoPair.self, LegacyCoupon.self]
    }

    @Model
    final class LegacyProject {
        @Attribute(.unique) var id: UUID
        var title: String
        var createdAt: Date
        var updatedAt: Date
        var latitude: Double?
        var longitude: Double?
        var locationLabel: String?

        @Relationship(deleteRule: .cascade, inverse: \LegacyPhotoPair.project)
        var pairs: [LegacyPhotoPair] = []

        init(
            title: String,
            latitude: Double? = nil,
            longitude: Double? = nil,
            locationLabel: String? = nil,
            createdAt: Date = .now
        ) {
            id = UUID()
            self.title = title
            self.createdAt = createdAt
            updatedAt = createdAt
            self.latitude = latitude
            self.longitude = longitude
            self.locationLabel = locationLabel
        }
    }

    @Model
    final class LegacyPhotoPair {
        @Attribute(.unique) var id: UUID
        var beforePath: String
        var afterPath: String?
        var combinedPath: String?
        var beforeCapturedAt: Date
        var afterCapturedAt: Date?
        var statusRaw: String
        var beforeZoomFactor: Double
        var beforeLensIdentifier: String?

        var project: LegacyProject?

        init(
            beforePath: String,
            beforeZoomFactor: Double = 1.0,
            beforeLensIdentifier: String? = nil,
            capturedAt: Date = .now,
            project: LegacyProject? = nil
        ) {
            id = UUID()
            self.beforePath = beforePath
            beforeCapturedAt = capturedAt
            statusRaw = "pendingAfter"
            self.beforeZoomFactor = beforeZoomFactor
            self.beforeLensIdentifier = beforeLensIdentifier
            self.project = project
        }
    }

    @Model
    final class LegacyCoupon {
        @Attribute(.unique) var id: UUID
        var code: String
        var activatedAt: Date
        var durationDays: Int
        var signatureBase64: String
        var statusRaw: String

        init(
            code: String,
            activatedAt: Date = .now,
            durationDays: Int,
            signatureBase64: String,
            statusRaw: String = "active"
        ) {
            id = UUID()
            self.code = code
            self.activatedAt = activatedAt
            self.durationDays = durationDays
            self.signatureBase64 = signatureBase64
            self.statusRaw = statusRaw
        }
    }
}
