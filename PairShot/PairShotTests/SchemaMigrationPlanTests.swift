import Foundation
@testable import PairShot
import SwiftData
import XCTest

@MainActor
final class SchemaMigrationPlanTests: XCTestCase {
    func testMigrationPlanRegistersBothSchemas() {
        let schemas = PairShotMigrationPlan.schemas
        XCTAssertEqual(schemas.count, 2)
        XCTAssertTrue(schemas.contains(where: { $0 == SchemaV1.self }))
        XCTAssertTrue(schemas.contains(where: { $0 == SchemaV2.self }))
    }

    func testMigrationPlanExposesV1ToV2Stage() {
        XCTAssertEqual(PairShotMigrationPlan.stages.count, 1)
    }

    func testFileNameExtractionStripsLeadingDirectory() {
        XCTAssertEqual(V1ToV2Migrator.extractFileName("photos/abc.jpg"), "abc.jpg")
        XCTAssertEqual(V1ToV2Migrator.extractFileName("abc.jpg"), "abc.jpg")
        XCTAssertEqual(V1ToV2Migrator.extractFileName(""), "")
    }

    func testLensPositionMappingForKnownIdentifiers() {
        XCTAssertEqual(V1ToV2Migrator.lensPosition(for: "BuiltInUltraWideCamera.back"), .backUltraWide)
        XCTAssertEqual(V1ToV2Migrator.lensPosition(for: "BuiltInTelephotoCamera.back"), .backTele)
        XCTAssertEqual(V1ToV2Migrator.lensPosition(for: "BuiltInWideAngleCamera.front"), .front)
        XCTAssertEqual(V1ToV2Migrator.lensPosition(for: "BuiltInWideAngleCamera.back"), .backWide)
        XCTAssertEqual(V1ToV2Migrator.lensPosition(for: nil), .backWide)
    }

    func testV1FreshContainerOpensWithLegacyModels() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let project = SchemaV1.LegacyProject(title: "Legacy Project A")
        context.insert(project)
        try context.save()

        let projects = try context.fetch(FetchDescriptor<SchemaV1.LegacyProject>())
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects.first?.title, "Legacy Project A")
    }

    func testV2FreshContainerOpensWithNewModels() throws {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let album = Album(name: "Migrated A")
        context.insert(album)
        try context.save()

        let albums = try context.fetch(FetchDescriptor<Album>())
        XCTAssertEqual(albums.count, 1)
    }

    func testWillMigrateAndDidMigrateRoundTripPreservesShape() throws {
        let v1Schema = Schema(versionedSchema: SchemaV1.self)
        let v1Container = try ModelContainer(
            for: v1Schema,
            configurations: [ModelConfiguration(schema: v1Schema, isStoredInMemoryOnly: true)]
        )
        let v1Context = ModelContext(v1Container)

        let project = SchemaV1.LegacyProject(
            title: "Site B",
            latitude: 37.5,
            longitude: 127.1,
            locationLabel: "강남구"
        )
        v1Context.insert(project)
        let pair = SchemaV1.LegacyPhotoPair(
            beforePath: "photos/before-001.jpg",
            beforeZoomFactor: 2.0,
            beforeLensIdentifier: "BuiltInWideAngleCamera.back",
            project: project
        )
        v1Context.insert(pair)
        try v1Context.save()

        try V1ToV2Migrator.willMigrate(context: v1Context)
        XCTAssertEqual(V1ToV2Migrator.capturedSnapshots.count, 1)
        XCTAssertEqual(V1ToV2Migrator.capturedSnapshots.first?.projectTitle, "Site B")

        let v2Schema = Schema(versionedSchema: SchemaV2.self)
        let v2Container = try ModelContainer(
            for: v2Schema,
            configurations: [ModelConfiguration(schema: v2Schema, isStoredInMemoryOnly: true)]
        )
        let v2Context = ModelContext(v2Container)

        try V1ToV2Migrator.didMigrate(context: v2Context)

        let albums = try v2Context.fetch(FetchDescriptor<Album>())
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(albums.first?.name, "Site B")
        XCTAssertEqual(albums.first?.latitude, 37.5)

        let pairs = try v2Context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.beforeFileName, "before-001.jpg")
        XCTAssertEqual(pairs.first?.latitude, 37.5)
        XCTAssertEqual(pairs.first?.cameraSettings?.zoomFactor, 2.0)
        XCTAssertEqual(pairs.first?.albums.count, 1)
        XCTAssertEqual(pairs.first?.albums.first?.name, "Site B")
    }

    deinit {}
}
