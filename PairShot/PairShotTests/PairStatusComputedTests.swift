import Foundation
@testable import PairShot
import XCTest

final class PairStatusComputedTests: XCTestCase {
    func testFreshPairWithOnlyBeforeIsScheduled() {
        let pair = PhotoPair(beforeFileName: "before.jpg")
        XCTAssertEqual(pair.status, .scheduled)
    }

    func testPairWithAfterButNoCombinedIsCaptured() {
        let pair = PhotoPair(beforeFileName: "before.jpg")
        pair.afterFileName = "after.jpg"
        XCTAssertEqual(pair.status, .captured)
    }

    func testPairWithCombinedIsCombinedRegardlessOfAfter() {
        let pair = PhotoPair(beforeFileName: "before.jpg")
        pair.afterFileName = "after.jpg"
        pair.combinedFileName = "combined.jpg"
        XCTAssertEqual(pair.status, .combined)
    }

    func testPairWithCombinedButNilAfterIsCombinedAlready() {
        // edge: spec says combined is generated automatically once After is
        // captured, but defensively we still report .combined when the file
        // name is present even if after was somehow cleared later.
        let pair = PhotoPair(beforeFileName: "before.jpg")
        pair.combinedFileName = "combined.jpg"
        XCTAssertEqual(pair.status, .combined)
    }

    func testStatusEnumIsExhaustive() {
        XCTAssertEqual(PairStatus.allCases, [.scheduled, .captured, .combined])
    }

    deinit {}
}
