import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P4.2 — `GalleryFilter` predicate behaviour.
@MainActor
final class GalleryFilterTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - happy

    func testAllReturnsAllPairsRegardlessOfStatus() {
        let project = Project(title: "현장")
        let pending = PhotoPair(beforePath: "p/a.jpg", project: project)
        let complete = PhotoPair(beforePath: "p/b.jpg", project: project)
        complete.status = .complete
        complete.afterPath = "p/b-after.jpg"
        let composited = PhotoPair(beforePath: "p/c.jpg", project: project)
        composited.status = .complete
        composited.afterPath = "p/c-after.jpg"
        composited.combinedPath = "p/c-combined.jpg"

        let pairs = [pending, complete, composited]
        let result = GalleryFilter.all.apply(to: pairs)

        XCTAssertEqual(result.count, 3)
    }

    func testCombinedOnlyReturnsOnlyPairsWithNonEmptyCombinedPath() {
        let project = Project(title: "현장")
        let pending = PhotoPair(beforePath: "p/a.jpg", project: project)
        let complete = PhotoPair(beforePath: "p/b.jpg", project: project)
        complete.status = .complete
        let composited = PhotoPair(beforePath: "p/c.jpg", project: project)
        composited.combinedPath = "p/c-combined.jpg"

        let pairs = [pending, complete, composited]
        let result = GalleryFilter.combinedOnly.apply(to: pairs)

        XCTAssertEqual(result.map(\.beforePath), ["p/c.jpg"])
    }

    // MARK: - edge

    func testCombinedOnlyTreatsEmptyStringAsNoComposite() {
        let pair = PhotoPair(beforePath: "p/x.jpg")
        pair.combinedPath = ""

        let result = GalleryFilter.combinedOnly.apply(to: [pair])

        XCTAssertTrue(result.isEmpty)
    }

    func testFiltersAreStableOnEmptyInput() {
        XCTAssertEqual(GalleryFilter.all.apply(to: []).count, 0)
        XCTAssertEqual(GalleryFilter.combinedOnly.apply(to: []).count, 0)
    }

    func testAllCasesIncludeBothFilters() {
        XCTAssertEqual(GalleryFilter.allCases, [.all, .combinedOnly])
    }

    func testLabelsAreLocalizedAndDistinct() {
        XCTAssertNotEqual(GalleryFilter.all.label, GalleryFilter.combinedOnly.label)
        XCTAssertFalse(GalleryFilter.all.label.isEmpty)
        XCTAssertFalse(GalleryFilter.combinedOnly.label.isEmpty)
    }
}
