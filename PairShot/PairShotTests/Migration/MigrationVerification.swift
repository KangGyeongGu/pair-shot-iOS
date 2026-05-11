@testable import PairShot
import SwiftData
import XCTest

final class MigrationVerification: XCTestCase {
    func testCurrentSchemaContainerOpens() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PairShotMigrationPlan.self,
            configurations: [configuration]
        )
        XCTAssertNotNil(container)
    }
}
