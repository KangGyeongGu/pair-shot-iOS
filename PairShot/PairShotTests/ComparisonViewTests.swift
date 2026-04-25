import Foundation
@testable import PairShot
import SwiftData
import SwiftUI
import XCTest

/// P5.1 — `ComparisonView` pager arithmetic + initialiser plumbing.
///
/// SwiftUI gestures aren't directly testable; the pure
/// `ComparisonPager` helpers stand in as the unit-test seam. The view's
/// `body` is exercised by the build (preview compiles).
@MainActor
final class ComparisonViewTests: XCTestCase {
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

    func testPagerNextStepsForwardWithinBounds() {
        XCTAssertEqual(ComparisonPager.next(index: 0, count: 3), 1)
        XCTAssertEqual(ComparisonPager.next(index: 1, count: 3), 2)
    }

    func testPagerPreviousStepsBackwardWithinBounds() {
        XCTAssertEqual(ComparisonPager.previous(index: 2, count: 3), 1)
        XCTAssertEqual(ComparisonPager.previous(index: 1, count: 3), 0)
    }

    func testPagerLabelIsOneBased() {
        XCTAssertEqual(ComparisonPager.label(index: 0, count: 5), "1 / 5")
        XCTAssertEqual(ComparisonPager.label(index: 4, count: 5), "5 / 5")
    }

    func testInitClampsStartIndexToValidRange() {
        let project = Project(title: "현장")
        context.insert(project)
        let p1 = PhotoPair(beforePath: "p/a.jpg", project: project)
        let p2 = PhotoPair(beforePath: "p/b.jpg", project: project)
        context.insert(p1)
        context.insert(p2)
        try? context.save()

        let view = ComparisonView(pairs: [p1, p2], startIndex: 99)
        // Initial state initialiser runs `max(0, min(start, count-1))`.
        XCTAssertEqual(view.index, 1)
    }

    func testViewModeAllCasesCoverThreeOptions() {
        XCTAssertEqual(ComparisonView.ViewMode.allCases.count, 3)
        XCTAssertTrue(ComparisonView.ViewMode.allCases.contains(.split))
        XCTAssertTrue(ComparisonView.ViewMode.allCases.contains(.beforeOnly))
        XCTAssertTrue(ComparisonView.ViewMode.allCases.contains(.afterOnly))
    }

    // MARK: - edge

    func testPagerNextClampsAtLastIndex() {
        XCTAssertEqual(ComparisonPager.next(index: 4, count: 5), 4)
        XCTAssertEqual(ComparisonPager.next(index: 9, count: 5), 4)
    }

    func testPagerPreviousClampsAtZero() {
        XCTAssertEqual(ComparisonPager.previous(index: 0, count: 5), 0)
        XCTAssertEqual(ComparisonPager.previous(index: -3, count: 5), 0)
    }

    func testPagerHandlesEmptyCount() {
        XCTAssertEqual(ComparisonPager.next(index: 0, count: 0), 0)
        XCTAssertEqual(ComparisonPager.previous(index: 0, count: 0), 0)
        XCTAssertEqual(ComparisonPager.label(index: 0, count: 0), "")
    }

    func testPagerLabelClampsOutOfRangeIndex() {
        XCTAssertEqual(ComparisonPager.label(index: 99, count: 3), "3 / 3")
        XCTAssertEqual(ComparisonPager.label(index: -5, count: 3), "1 / 3")
    }

    func testImageLoaderReturnsNilForBlankPath() {
        let storage = PhotoStorageService(baseDirectory: FileManager.default.temporaryDirectory)
        XCTAssertNil(ComparisonImageLoader.load(relativePath: "", storage: storage))
    }

    func testImageLoaderReturnsNilForMissingFile() {
        let storage = PhotoStorageService(baseDirectory: FileManager.default.temporaryDirectory)
        XCTAssertNil(ComparisonImageLoader.load(
            relativePath: "photos/nonexistent-\(UUID().uuidString).jpg",
            storage: storage
        ))
    }
}
