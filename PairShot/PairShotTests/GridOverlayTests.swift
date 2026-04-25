@testable import PairShot
import SwiftUI
import XCTest

/// P2.5 — grid overlay smoke tests.
@MainActor
final class GridOverlayTests: XCTestCase {
    // MARK: - happy

    func testGridUsesThreeDivisionsByDefault() {
        let grid = GridOverlay()
        XCTAssertEqual(grid.divisions, 3)
    }

    func testCustomDivisionsAreHonoured() {
        let grid = GridOverlay(divisions: 5)
        XCTAssertEqual(grid.divisions, 5)
    }

    // MARK: - edge

    func testZeroDivisionsRendersWithoutCrash() {
        // Edge case — divisions=0 means no interior lines. We render but the
        // canvas is empty; we just verify the value flows through.
        let grid = GridOverlay(divisions: 0)
        XCTAssertEqual(grid.divisions, 0)
    }

    func testLevelIndicatorRendersForBothSigns() {
        let positive = LevelIndicator(rollDegrees: 4.5)
        let negative = LevelIndicator(rollDegrees: -4.5)
        // We only smoke-check construction; SwiftUI snapshot is out of scope.
        XCTAssertEqual(positive.rollDegrees, 4.5)
        XCTAssertEqual(negative.rollDegrees, -4.5)
    }
}
