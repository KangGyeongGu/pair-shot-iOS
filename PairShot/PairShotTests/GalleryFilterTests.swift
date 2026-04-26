import Foundation
@testable import PairShot
import SwiftData
import XCTest

@MainActor
final class GalleryFilterTests: XCTestCase {
    func testAllReturnsAllPairsRegardlessOfStatus() {
        let pending = PhotoPair(beforeFileName: "before_a.jpg")
        let captured = PhotoPair(beforeFileName: "before_b.jpg")
        captured.afterFileName = "after_b.jpg"
        let combined = PhotoPair(beforeFileName: "before_c.jpg")
        combined.afterFileName = "after_c.jpg"
        combined.combinedFileName = "combined_c.jpg"

        let pairs = [pending, captured, combined]
        XCTAssertEqual(GalleryFilter.all.apply(to: pairs).count, 3)
    }

    func testCombinedOnlyReturnsOnlyPairsWithNonEmptyCombinedFileName() {
        let pending = PhotoPair(beforeFileName: "before_a.jpg")
        let captured = PhotoPair(beforeFileName: "before_b.jpg")
        captured.afterFileName = "after_b.jpg"
        let combined = PhotoPair(beforeFileName: "before_c.jpg")
        combined.combinedFileName = "combined_c.jpg"

        let result = GalleryFilter.combinedOnly.apply(to: [pending, captured, combined])
        XCTAssertEqual(result.map(\.beforeFileName), ["before_c.jpg"])
    }

    func testCombinedOnlyTreatsEmptyStringAsNoComposite() {
        let pair = PhotoPair(beforeFileName: "before_x.jpg")
        pair.combinedFileName = ""
        XCTAssertTrue(GalleryFilter.combinedOnly.apply(to: [pair]).isEmpty)
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

    deinit {}
}
