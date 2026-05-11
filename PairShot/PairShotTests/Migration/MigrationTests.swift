@testable import PairShot
import SwiftData
import Testing

struct MigrationTests {
    @Test("SchemaV1 in-memory container opens without error")
    func schemaV1OpensCleanly() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PairShotMigrationPlan.self,
            configurations: [configuration]
        )
        #expect(container.schema.entities.count == 3)
    }

    @Test("PairShotMigrationPlan declares SchemaV1")
    func migrationPlanIncludesV1() {
        let schemas = PairShotMigrationPlan.schemas
        let schemaV1Identifier = ObjectIdentifier(SchemaV1.self)
        #expect(schemas.contains { ObjectIdentifier($0) == schemaV1Identifier })
    }
}
