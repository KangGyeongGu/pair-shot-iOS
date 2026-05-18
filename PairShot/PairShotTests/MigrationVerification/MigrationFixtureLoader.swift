import Foundation
import SwiftData

@MainActor
enum MigrationFixtureLoader {
    static func loadContainer(
        url: URL,
        schema: any VersionedSchema.Type,
        migrationPlan: any SchemaMigrationPlan.Type,
    ) throws -> ModelContainer {
        let schemaInstance = Schema(versionedSchema: schema)
        let config = ModelConfiguration(schema: schemaInstance, url: url)
        return try ModelContainer(
            for: schemaInstance,
            migrationPlan: migrationPlan,
            configurations: [config],
        )
    }

    static func makeTemporaryStoreURL(prefix: String = "migration-test") -> URL {
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
    }

    static func cleanup(url: URL) {
        let directory = url.deletingPathExtension()
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: directory)
        let baseName = url.deletingPathExtension().lastPathComponent
        let parentDir = url.deletingLastPathComponent()
        let walFile = parentDir.appendingPathComponent("\(baseName).sqlite-wal")
        let shmFile = parentDir.appendingPathComponent("\(baseName).sqlite-shm")
        try? FileManager.default.removeItem(at: walFile)
        try? FileManager.default.removeItem(at: shmFile)
    }
}
