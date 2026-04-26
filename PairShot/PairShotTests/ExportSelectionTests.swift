import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P7.1 — pure-function selection: which paths land in the archive given an
/// `ExportMode` and a `PhotoPair`'s available paths.
@MainActor
final class ExportSelectionTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - happy

    func testAllModeIncludesEverythingPresent() throws {
        let project = Project(title: "현장")
        context.insert(project)
        let pair = PhotoPair(beforePath: "photos/b.jpg", project: project)
        pair.afterPath = "photos/a.jpg"
        pair.combinedPath = "photos/c.jpg"
        context.insert(pair)
        try context.save()

        let entries = ExportSelection.relativePaths(for: pair, mode: .all)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map(\.sourcePath).sorted(), ["photos/a.jpg", "photos/b.jpg", "photos/c.jpg"])
        for entry in entries {
            XCTAssertTrue(entry.relativeName.hasPrefix("현장/"))
        }
    }

    func testBeforeOnlyIncludesOnlyBefore() throws {
        let project = Project(title: "Site")
        context.insert(project)
        let pair = PhotoPair(beforePath: "photos/b.jpg", project: project)
        pair.afterPath = "photos/a.jpg"
        pair.combinedPath = "photos/c.jpg"
        context.insert(pair)
        try context.save()

        let entries = ExportSelection.relativePaths(for: pair, mode: .beforeOnly)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].sourcePath, "photos/b.jpg")
        XCTAssertTrue(entries[0].relativeName.contains("_before.jpg"))
    }

    func testAfterOnlyMissingAfterReturnsEmpty() throws {
        let project = Project(title: "Site")
        context.insert(project)
        let pair = PhotoPair(beforePath: "photos/b.jpg", project: project)
        // No afterPath set — pending pair.
        context.insert(pair)
        try context.save()

        let entries = ExportSelection.relativePaths(for: pair, mode: .afterOnly)
        XCTAssertTrue(entries.isEmpty)
    }

    func testCombinedOnlyMissingCombinedReturnsEmpty() throws {
        let project = Project(title: "Site")
        context.insert(project)
        let pair = PhotoPair(beforePath: "photos/b.jpg", project: project)
        pair.afterPath = "photos/a.jpg"
        pair.combinedPath = nil
        context.insert(pair)
        try context.save()

        let entries = ExportSelection.relativePaths(for: pair, mode: .combinedOnly)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - edge

    func testFolderNameSanitizesForbiddenCharacters() {
        XCTAssertEqual(ExportSelection.sanitizeFolderName("Site/A:B"), "Site_A_B")
        XCTAssertEqual(ExportSelection.sanitizeFolderName(""), "PairShot")
        XCTAssertEqual(ExportSelection.sanitizeFolderName("   "), "PairShot")
        XCTAssertEqual(ExportSelection.sanitizeFolderName("현장 1"), "현장_1")
    }

    func testNameStemUsesPairUUID() throws {
        let project = Project(title: "현장")
        context.insert(project)
        let pair = PhotoPair(beforePath: "photos/x.jpg", project: project)
        context.insert(pair)
        try context.save()

        let entries = ExportSelection.relativePaths(for: pair, mode: .beforeOnly)
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].relativeName.contains(pair.id.uuidString))
    }

    func testProjectlessPairFallsBackToDefaultFolder() {
        let pair = PhotoPair(beforePath: "photos/x.jpg")
        // Not inserted into a project — sanitize fallback should kick in.
        let entries = ExportSelection.relativePaths(for: pair, mode: .beforeOnly)
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].relativeName.hasPrefix("PairShot/"))
    }

    func testAllModeSkipsEmptyOptionalPaths() throws {
        let project = Project(title: "현장")
        context.insert(project)
        let pair = PhotoPair(beforePath: "photos/b.jpg", project: project)
        pair.afterPath = ""
        pair.combinedPath = ""
        context.insert(pair)
        try context.save()

        let entries = ExportSelection.relativePaths(for: pair, mode: .all)
        // Only `before` survives — the empty strings are treated as absent.
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].sourcePath, "photos/b.jpg")
    }
}
