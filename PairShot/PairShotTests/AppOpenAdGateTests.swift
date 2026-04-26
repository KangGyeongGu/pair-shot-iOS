import Foundation
@testable import PairShot
import XCTest

/// P6.9 — `AppOpenAdGate.shouldPresent(...)` is the pure decision the
/// `AppOpenAdManager` consults before asking the SDK to present.
///
/// Cold-start vs background→foreground are treated symmetrically: both
/// must respect the same minimum elapsed gap (default 4 minutes) so a
/// fast app-quit-and-relaunch can't bypass the cap.
final class AppOpenAdGateTests: XCTestCase {
    private let interval = AppOpenAdGate.defaultMinimumInterval

    // MARK: - happy

    func testColdStartWithNoPriorAllowsPresentation() {
        XCTAssertTrue(
            AppOpenAdGate.shouldPresent(
                coldStart: true,
                lastShownAt: nil,
                now: Date(timeIntervalSince1970: 1000),
                minimumInterval: interval
            )
        )
    }

    func testForegroundReturnWithNoPriorAllowsPresentation() {
        XCTAssertTrue(
            AppOpenAdGate.shouldPresent(
                coldStart: false,
                lastShownAt: nil,
                now: Date(timeIntervalSince1970: 1000),
                minimumInterval: interval
            )
        )
    }

    func testForegroundReturnPastCapAllowsPresentation() {
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(interval + 1)
        XCTAssertTrue(
            AppOpenAdGate.shouldPresent(
                coldStart: false,
                lastShownAt: last,
                now: now,
                minimumInterval: interval
            )
        )
    }

    func testColdStartPastCapAllowsPresentation() {
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(interval + 1)
        XCTAssertTrue(
            AppOpenAdGate.shouldPresent(
                coldStart: true,
                lastShownAt: last,
                now: now,
                minimumInterval: interval
            )
        )
    }

    // MARK: - edge

    func testForegroundReturnWithinCapDeniesPresentation() {
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(interval - 30)
        XCTAssertFalse(
            AppOpenAdGate.shouldPresent(
                coldStart: false,
                lastShownAt: last,
                now: now,
                minimumInterval: interval
            )
        )
    }

    func testColdStartWithinCapDeniesPresentation() {
        // A user who quickly relaunches must still be capped — otherwise
        // the cap is trivially defeatable.
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(interval - 1)
        XCTAssertFalse(
            AppOpenAdGate.shouldPresent(
                coldStart: true,
                lastShownAt: last,
                now: now,
                minimumInterval: interval
            )
        )
    }

    func testDefaultIntervalIsFourMinutes() {
        XCTAssertEqual(AppOpenAdGate.defaultMinimumInterval, 240)
    }

    func testExactlyAtIntervalAllowsPresentation() {
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(interval) // boundary case
        XCTAssertTrue(
            AppOpenAdGate.shouldPresent(
                coldStart: false,
                lastShownAt: last,
                now: now,
                minimumInterval: interval
            )
        )
    }
}
