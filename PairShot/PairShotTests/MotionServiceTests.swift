import CoreMotion
@testable import PairShot
import XCTest

/// P2.5 — Core Motion roll polling.
@MainActor
final class MotionServiceTests: XCTestCase {
    // MARK: - happy

    func testInitialRollIsZero() {
        let service = MotionService()
        XCTAssertEqual(service.rollDegrees, 0, accuracy: 1e-9)
        XCTAssertFalse(service.isStreaming)
    }

    func testIsLevelTrueAtZeroRoll() {
        let service = MotionService()
        XCTAssertTrue(service.isLevel())
    }

    func testIsLevelHonoursTolerance() {
        let service = MotionService()
        service.rollDegrees = 1.0
        XCTAssertTrue(service.isLevel(tolerance: 1.5))
        XCTAssertFalse(service.isLevel(tolerance: 0.5))
    }

    func testStopIsSafeBeforeStart() {
        let service = MotionService()
        service.stop() // must not crash
        XCTAssertFalse(service.isStreaming)
    }

    // MARK: - edge

    func testStartStopWithUnavailableManagerStaysIdle() {
        // Simulator: deviceMotion is unavailable. start() should silently noop.
        let service = MotionService()
        service.start()
        // We do not assert isStreaming==true because real devices answer differently.
        // Stopping must be safe regardless of state.
        service.stop()
        XCTAssertFalse(service.isStreaming)
    }

    func testCustomUpdateIntervalIsRecorded() {
        let service = MotionService(updateInterval: 0.25)
        XCTAssertEqual(service.updateInterval, 0.25, accuracy: 1e-9)
    }

    func testNegativeRollHandledByIsLevel() {
        let service = MotionService()
        service.rollDegrees = -1.0
        XCTAssertTrue(
            service.isLevel(tolerance: 1.5),
            "isLevel must use absolute value"
        )
    }
}
