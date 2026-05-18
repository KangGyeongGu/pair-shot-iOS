import Foundation
@testable import PairShot
import SwiftData

@Model
final class TestMigrationEntity {
    @Attribute(.unique) var id: UUID
    var label: String

    init(label: String) {
        id = UUID()
        self.label = label
    }
}

enum TestSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            AlbumEntity.self,
            PhotoPairEntity.self,
            ExportHistoryEntity.self,
            TestMigrationEntity.self,
        ]
    }
}

enum TestMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, TestSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: TestSchemaV2.self),
        ]
    }
}
