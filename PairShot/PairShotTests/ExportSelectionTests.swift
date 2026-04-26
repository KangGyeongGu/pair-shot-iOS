import Foundation
@testable import PairShot
import SwiftData
import XCTest

@MainActor
final class ExportSelectionTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func testAllModeIncludesEverythingPresent() throws {
        let album = Album(name: "현장")
        context.insert(album)
        let pair = PhotoPair(beforeFileName: "b.jpg")
        pair.afterFileName = "a.jpg"
        pair.combinedFileName = "c.jpg"
        pair.albums.append(album)
        context.insert(pair)
        try context.save()

        let entries = ExportSelection.relativePaths(for: pair, mode: .all)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(
            entries.map(\.sourceFileName).sorted(),
            ["a.jpg", "b.jpg", "c.jpg"]
        )
        for entry in entries {
            XCTAssertTrue(entry.relativeName.hasPrefix("현장/"))
        }
    }

    func testBeforeOnlyIncludesOnlyBefore() throws {
        let album = Album(name: "Site")
        context.insert(album)
        let pair = PhotoPair(beforeFileName: "b.jpg")
        pair.afterFileName = "a.jpg"
        pair.combinedFileName = "c.jpg"
        pair.albums.append(album)
        context.insert(pair)
        try context.save()

        let entries = ExportSelection.relativePaths(for: pair, mode: .beforeOnly)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].sourceFileName, "b.jpg")
        XCTAssertTrue(entries[0].relativeName.contains("_before.jpg"))
    }

    func testAfterOnlyMissingAfterReturnsEmpty() throws {
        let album = Album(name: "Site")
        context.insert(album)
        let pair = PhotoPair(beforeFileName: "b.jpg")
        pair.albums.append(album)
        context.insert(pair)
        try context.save()

        let entries = ExportSelection.relativePaths(for: pair, mode: .afterOnly)
        XCTAssertTrue(entries.isEmpty)
    }

    func testCombinedOnlyMissingCombinedReturnsEmpty() throws {
        let album = Album(name: "Site")
        context.insert(album)
        let pair = PhotoPair(beforeFileName: "b.jpg")
        pair.afterFileName = "a.jpg"
        pair.albums.append(album)
        context.insert(pair)
        try context.save()

        let entries = ExportSelection.relativePaths(for: pair, mode: .combinedOnly)
        XCTAssertTrue(entries.isEmpty)
    }

    func testFolderNameSanitizesForbiddenCharacters() {
        XCTAssertEqual(ExportSelection.sanitizeFolderName("Site/A:B"), "Site_A_B")
        XCTAssertEqual(ExportSelection.sanitizeFolderName(""), "PairShot")
        XCTAssertEqual(ExportSelection.sanitizeFolderName("   "), "PairShot")
        XCTAssertEqual(ExportSelection.sanitizeFolderName("현장 1"), "현장_1")
    }

    func testFolderNameFallsBackWhenPairHasNoAlbum() throws {
        let pair = PhotoPair(beforeFileName: "x.jpg")
        context.insert(pair)
        try context.save()
        let entries = ExportSelection.relativePaths(for: pair, mode: .beforeOnly)
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].relativeName.hasPrefix("PairShot/"))
    }

    deinit {}
}
