@preconcurrency import AVFoundation
@testable import PairShot
import XCTest

/// P2.4 — tap-to-focus + drag-EV math.
final class FocusGestureTests: XCTestCase {
    // MARK: - drag → bias mapping

    func testFullUpwardDragMapsToMaxBias() {
        let bias = FocusGestureMath.biasForDrag(
            dragY: -800,
            viewHeight: 800,
            startBias: 0,
            range: -2.0 ... 2.0
        )
        XCTAssertEqual(bias, 2.0, accuracy: 1e-4, "Full upward drag should clamp to max bias")
    }

    func testFullDownwardDragMapsToMinBias() {
        let bias = FocusGestureMath.biasForDrag(
            dragY: 800,
            viewHeight: 800,
            startBias: 0,
            range: -2.0 ... 2.0
        )
        XCTAssertEqual(bias, -2.0, accuracy: 1e-4, "Full downward drag should clamp to min bias")
    }

    func testHalfDragMovesHalfTheRange() {
        let bias = FocusGestureMath.biasForDrag(
            dragY: -400,
            viewHeight: 800,
            startBias: 0,
            range: -2.0 ... 2.0
        )
        // Half upward = +span/2 = +2.0
        XCTAssertEqual(bias, 2.0, accuracy: 1e-4)
    }

    // MARK: - edge

    func testZeroViewHeightReturnsStartBias() {
        let bias = FocusGestureMath.biasForDrag(
            dragY: -50,
            viewHeight: 0,
            startBias: 1.0,
            range: -3.0 ... 3.0
        )
        XCTAssertEqual(bias, 1.0, accuracy: 1e-4)
    }

    func testBiasIsClampedAboveRange() {
        let bias = FocusGestureMath.biasForDrag(
            dragY: -10000,
            viewHeight: 10,
            startBias: 0,
            range: -1.0 ... 1.0
        )
        XCTAssertEqual(bias, 1.0, accuracy: 1e-4, "Out-of-range drag must clamp")
    }

    @MainActor
    func testDevicePointFallsBackToCentreWhenNoLayer() {
        let p = FocusGestureMath.devicePoint(forTap: CGPoint(x: 100, y: 200), in: nil)
        XCTAssertEqual(p, CGPoint(x: 0.5, y: 0.5), "Without layer, must default to centre")
    }
}
