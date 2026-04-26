import Foundation
@testable import PairShot
import XCTest

/// P6.9 — `AppOpenAdGate.shouldPresent(...)` is the pure decision the
/// `AppOpenAdManager` consults before asking the SDK to present.
///
/// Audit-D — the `coldStart` parameter was removed from
/// `shouldPresent(...)` because both lifecycle paths (cold start,
/// background → foreground) share the same elapsed-since-last cap.
/// The cases below are renamed to drop the cold-start framing; the
/// underlying invariant is unchanged.
final class AppOpenAdGateTests: XCTestCase {
    private let interval = AppOpenAdGate.defaultMinimumInterval

    // MARK: - happy

    func testNoPriorAllowsPresentation() {
        XCTAssertTrue(
            AppOpenAdGate.shouldPresent(
                lastShownAt: nil,
                now: Date(timeIntervalSince1970: 1000),
                minimumInterval: interval
            )
        )
    }

    func testNoPriorAllowsPresentationOnSecondCall() {
        // Sanity replicate of the happy case under a fresh `now` —
        // ensures `nil` lastShown short-circuits regardless of clock.
        XCTAssertTrue(
            AppOpenAdGate.shouldPresent(
                lastShownAt: nil,
                now: Date(timeIntervalSince1970: 5_000_000),
                minimumInterval: interval
            )
        )
    }

    func testPastCapAllowsPresentation() {
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(interval + 1)
        XCTAssertTrue(
            AppOpenAdGate.shouldPresent(
                lastShownAt: last,
                now: now,
                minimumInterval: interval
            )
        )
    }

    func testFarPastCapAllowsPresentation() {
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(interval * 10)
        XCTAssertTrue(
            AppOpenAdGate.shouldPresent(
                lastShownAt: last,
                now: now,
                minimumInterval: interval
            )
        )
    }

    // MARK: - edge

    func testWithinCapDeniesPresentation() {
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(interval - 30)
        XCTAssertFalse(
            AppOpenAdGate.shouldPresent(
                lastShownAt: last,
                now: now,
                minimumInterval: interval
            )
        )
    }

    func testJustBelowCapDeniesPresentation() {
        // A user who quickly relaunches must still be capped — otherwise
        // the cap is trivially defeatable.
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(interval - 1)
        XCTAssertFalse(
            AppOpenAdGate.shouldPresent(
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
                lastShownAt: last,
                now: now,
                minimumInterval: interval
            )
        )
    }
}
