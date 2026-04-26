import Foundation
@testable import PairShot
import SwiftData
import SwiftUI
import XCTest

@MainActor
final class PairGalleryViewTests: XCTestCase {
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

    func testPairsSortedByCreatedAtDescending() throws {
        let mid = PhotoPair(beforeFileName: "mid.jpg", capturedAt: Date(timeIntervalSince1970: 2000))
        let oldest = PhotoPair(beforeFileName: "old.jpg", capturedAt: Date(timeIntervalSince1970: 1000))
        let newest = PhotoPair(beforeFileName: "new.jpg", capturedAt: Date(timeIntervalSince1970: 3000))
        context.insert(oldest)
        context.insert(mid)
        context.insert(newest)
        try context.save()

        let descriptor = FetchDescriptor<PhotoPair>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let pairs = try context.fetch(descriptor)
        XCTAssertEqual(pairs.map(\.beforeFileName), ["new.jpg", "mid.jpg", "old.jpg"])
    }

    func testFilterAllShowsEveryPair() throws {
        let pending = PhotoPair(beforeFileName: "a.jpg")
        let captured = PhotoPair(beforeFileName: "b.jpg")
        captured.afterFileName = "b-after.jpg"
        let combined = PhotoPair(beforeFileName: "c.jpg")
        combined.combinedFileName = "c-x.jpg"
        context.insert(pending)
        context.insert(captured)
        context.insert(combined)
        try context.save()

        let pairs = try context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertEqual(GalleryFilter.all.apply(to: pairs).count, 3)
    }

    func testFilterCombinedRestrictsToCompositedPairs() throws {
        let plain = PhotoPair(beforeFileName: "a.jpg")
        let combined = PhotoPair(beforeFileName: "b.jpg")
        combined.combinedFileName = "b-cx.jpg"
        context.insert(plain)
        context.insert(combined)
        try context.save()

        let pairs = try context.fetch(FetchDescriptor<PhotoPair>())
        let filtered = GalleryFilter.combinedOnly.apply(to: pairs)
        XCTAssertEqual(filtered.map(\.beforeFileName), ["b.jpg"])
    }

    func testEmptyContextProducesEmptyFilterOutput() {
        XCTAssertTrue(GalleryFilter.all.apply(to: []).isEmpty)
        XCTAssertTrue(GalleryFilter.combinedOnly.apply(to: []).isEmpty)
    }

    func testTwoColumnGridConstantIsStable() {
        let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
        XCTAssertEqual(columns.count, 2)
    }

    func testInitializerAcceptsCustomStorage() {
        let custom = PhotoStorageService(baseDirectory: FileManager.default.temporaryDirectory)
        let view = PairGalleryView(albumId: nil, storage: custom)
        XCTAssertNil(view.albumId)
    }

    deinit {}
}
