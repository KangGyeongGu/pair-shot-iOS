import Foundation
@testable import PairShot
import SwiftData
import XCTest

@MainActor
final class AlbumModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
    }

    func testAlbumInitDefaults() throws {
        let album = Album(name: "현장-A")
        context.insert(album)
        try context.save()

        XCTAssertFalse(album.id.uuidString.isEmpty)
        XCTAssertEqual(album.name, "현장-A")
        XCTAssertEqual(album.createdAt, album.updatedAt)
        XCTAssertNil(album.latitude)
        XCTAssertNil(album.longitude)
        XCTAssertNil(album.locationLabel)
        XCTAssertTrue(album.pairs.isEmpty)
    }

    func testAlbumInitWithGPS() throws {
        let album = Album(
            name: "GPS 현장",
            latitude: 37.5665,
            longitude: 126.978,
            locationLabel: "서울시 중구"
        )
        context.insert(album)
        try context.save()

        XCTAssertEqual(album.latitude, 37.5665)
        XCTAssertEqual(album.longitude, 126.978)
        XCTAssertEqual(album.locationLabel, "서울시 중구")
    }

    func testAlbumIdsAreUnique() {
        let a = Album(name: "A")
        let b = Album(name: "B")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testAlbumDeletionDoesNotCascadePairs() throws {
        let album = Album(name: "보존 테스트")
        context.insert(album)
        let pair = PhotoPair(beforeFileName: "x.jpg")
        pair.albums.append(album)
        context.insert(pair)
        try context.save()

        XCTAssertEqual(album.pairs.count, 1)
        XCTAssertEqual(pair.albums.count, 1)

        context.delete(album)
        try context.save()

        let remainingPairs = try context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertEqual(remainingPairs.count, 1, "spec 13.1: 앨범을 삭제하시겠습니까? 페어는 유지됩니다.")
    }

    func testKoreanUnicodeNamePreserved() throws {
        let name = "🏗️ 한국어 앨범 — 테스트"
        let album = Album(name: name)
        context.insert(album)
        try context.save()
        XCTAssertEqual(album.name, name)
    }

    func testEmptyNameIsAllowed() throws {
        let album = Album(name: "")
        context.insert(album)
        XCTAssertNoThrow(try context.save())
    }

    func testAlbumDeletionServiceDeletesByIdsButPreservesPairs() throws {
        let album1 = Album(name: "A")
        let album2 = Album(name: "B")
        context.insert(album1)
        context.insert(album2)
        let pair = PhotoPair(beforeFileName: "x.jpg")
        pair.albums.append(album1)
        pair.albums.append(album2)
        context.insert(pair)
        try context.save()

        let removed = try AlbumDeletionService.deleteAlbums(
            ids: [album1.id], in: context
        )
        XCTAssertEqual(removed, 1)
        let remainingAlbums = try context.fetch(FetchDescriptor<Album>())
        XCTAssertEqual(remainingAlbums.map(\.name), ["B"])
        let remainingPairs = try context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertEqual(remainingPairs.count, 1)
    }

    deinit {}
}
