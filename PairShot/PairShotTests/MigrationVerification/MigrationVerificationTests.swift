import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct MigrationVerificationTests {
    @Test
    func `T1 V1 round-trip 디스크 저장 후 같은 schema 로 재오픈 시 데이터 보존`() throws {
        let storeURL = MigrationFixtureLoader.makeTemporaryStoreURL()
        defer { MigrationFixtureLoader.cleanup(url: storeURL) }

        try MigrationFixtureStore.createV1Fixture(
            at: storeURL,
            albumCount: 2,
            pairCount: 5,
        )

        let reopened = try MigrationFixtureLoader.loadContainer(
            url: storeURL,
            schema: SchemaV1.self,
            migrationPlan: PairShotMigrationPlan.self,
        )
        let context = reopened.mainContext
        let albums = try context.fetch(FetchDescriptor<AlbumEntity>())
        let pairs = try context.fetch(FetchDescriptor<PhotoPairEntity>())

        #expect(albums.count == 2)
        #expect(pairs.count == 5)
    }

    @Test
    func `T2 V1 -> TestSchemaV2 lightweight 마이그레이션 자동 적용 + 데이터 보존`() throws {
        let storeURL = MigrationFixtureLoader.makeTemporaryStoreURL()
        defer { MigrationFixtureLoader.cleanup(url: storeURL) }

        try MigrationFixtureStore.createV1Fixture(
            at: storeURL,
            albumCount: 2,
            pairCount: 5,
        )

        let migrated = try MigrationFixtureLoader.loadContainer(
            url: storeURL,
            schema: TestSchemaV2.self,
            migrationPlan: TestMigrationPlan.self,
        )
        let context = migrated.mainContext

        let albums = try context.fetch(FetchDescriptor<AlbumEntity>())
        let pairs = try context.fetch(FetchDescriptor<PhotoPairEntity>())
        let testEntitiesBefore = try context.fetch(FetchDescriptor<TestMigrationEntity>())

        #expect(albums.count == 2)
        #expect(pairs.count == 5)
        #expect(testEntitiesBefore.isEmpty)

        context.insert(TestMigrationEntity(label: "after-migration"))
        try context.save()

        let testEntitiesAfter = try context.fetch(FetchDescriptor<TestMigrationEntity>())
        #expect(testEntitiesAfter.count == 1)
        #expect(testEntitiesAfter.first?.label == "after-migration")
    }

    @Test
    func `T3 마이그레이션 후 PhotoPair id 와 필드 무결성 유지`() throws {
        let storeURL = MigrationFixtureLoader.makeTemporaryStoreURL()
        defer { MigrationFixtureLoader.cleanup(url: storeURL) }

        let fixedId = UUID()
        let schemaV1 = Schema(versionedSchema: SchemaV1.self)
        let configV1 = ModelConfiguration(schema: schemaV1, url: storeURL)
        let containerV1 = try ModelContainer(
            for: schemaV1,
            migrationPlan: PairShotMigrationPlan.self,
            configurations: [configV1],
        )
        let contextV1 = containerV1.mainContext
        let pair = PhotoPairEntity(
            id: fixedId,
            beforePhotoLocalIdentifier: "before-fixed",
            afterPhotoLocalIdentifier: "after-fixed",
        )
        contextV1.insert(pair)
        try contextV1.save()

        let migrated = try MigrationFixtureLoader.loadContainer(
            url: storeURL,
            schema: TestSchemaV2.self,
            migrationPlan: TestMigrationPlan.self,
        )
        let fetched = try migrated.mainContext.fetch(FetchDescriptor<PhotoPairEntity>())
        let match = fetched.first { $0.id == fixedId }

        #expect(match != nil)
        #expect(match?.beforePhotoLocalIdentifier == "before-fixed")
        #expect(match?.afterPhotoLocalIdentifier == "after-fixed")
    }

    @Test
    func `T4 PairShotMigrationPlan 은 production V1 만 유지 (test V2 오염 없음)`() {
        let schemas = PairShotMigrationPlan.schemas
        let v1Id = ObjectIdentifier(SchemaV1.self)
        let v2Id = ObjectIdentifier(TestSchemaV2.self)

        #expect(schemas.count == 1)
        #expect(schemas.contains { ObjectIdentifier($0) == v1Id })
        #expect(!schemas.contains { ObjectIdentifier($0) == v2Id })
    }
}
