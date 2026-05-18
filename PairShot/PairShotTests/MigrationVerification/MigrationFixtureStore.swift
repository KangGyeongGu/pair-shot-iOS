import Foundation
@testable import PairShot
import SwiftData

@MainActor
enum MigrationFixtureStore {
    @discardableResult
    static func createV1Fixture(
        at url: URL,
        albumCount: Int,
        pairCount: Int,
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PairShotMigrationPlan.self,
            configurations: [config],
        )
        let context = container.mainContext

        for index in 0 ..< albumCount {
            let album = AlbumEntity(name: "Fixture Album \(index)")
            context.insert(album)
        }
        for index in 0 ..< pairCount {
            let pair = PhotoPairEntity(
                beforePhotoLocalIdentifier: "before-\(index)",
                afterPhotoLocalIdentifier: "after-\(index)",
            )
            context.insert(pair)
        }
        try context.save()
        return container
    }
}
