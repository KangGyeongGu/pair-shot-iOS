import Foundation
@testable import PairShot
import XCTest

/// P6.6 — `InterstitialFrequencyGate.shouldPresent(...)` is the pure
/// decision rule the manager uses to honour the 5-minute cap. Pulled
/// out of the manager so it can be unit-tested without spinning up the
/// SDK or reasoning about Date.now races.
final class InterstitialFrequencyCapTests: XCTestCase {
    private let interval: TimeInterval = 300

    // MARK: - happy

    func testNoPriorPresentationAllowsImmediately() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(
            InterstitialFrequencyGate.shouldPresent(
                now: now,
                lastShownAt: nil,
                minimumInterval: interval
            )
        )
    }

    func testEnoughElapsedTimeAllowsPresentation() {
        let last = Date(timeIntervalSince1970: 1_000_000)
        let now = last.addingTimeInterval(interval) // exactly 300s later
        XCTAssertTrue(
            InterstitialFrequencyGate.shouldPresent(
                now: now,
                lastShownAt: last,
                minimumInterval: interval
            )
        )
    }

    func testWellPastIntervalAllowsPresentation() {
        let last = Date(timeIntervalSince1970: 1_000_000)
        let now = last.addingTimeInterval(3600) // an hour later
        XCTAssertTrue(
            InterstitialFrequencyGate.shouldPresent(
                now: now,
                lastShownAt: last,
                minimumInterval: interval
            )
        )
    }

    // MARK: - edge

    func testWithinIntervalDeniesPresentation() {
        let last = Date(timeIntervalSince1970: 1_000_000)
        let now = last.addingTimeInterval(interval - 1)
        XCTAssertFalse(
            InterstitialFrequencyGate.shouldPresent(
                now: now,
                lastShownAt: last,
                minimumInterval: interval
            )
        )
    }

    func testZeroIntervalAlwaysAllows() {
        // Interval of 0 disables the cap — useful for tests of the
        // surrounding manager that don't care about timing.
        let last = Date(timeIntervalSince1970: 1_000_000)
        let now = last.addingTimeInterval(0)
        XCTAssertTrue(
            InterstitialFrequencyGate.shouldPresent(
                now: now,
                lastShownAt: last,
                minimumInterval: 0
            )
        )
    }

    func testClockSkewBackwardsDeniesPresentation() {
        // If `now` somehow precedes `lastShownAt` (manual clock change),
        // elapsed is negative; cap should still apply (deny). We don't
        // want to hand the user an "unlocked" interstitial just because
        // they twiddled their clock.
        let last = Date(timeIntervalSince1970: 1_000_000)
        let now = last.addingTimeInterval(-60)
        XCTAssertFalse(
            InterstitialFrequencyGate.shouldPresent(
                now: now,
                lastShownAt: last,
                minimumInterval: interval
            )
        )
    }

    func testManagerDefaultIntervalIsFiveMinutes() {
        // Pin the default so a stray edit can't silently relax the cap.
        XCTAssertEqual(InterstitialAdManager.defaultMinimumInterval, 300)
    }
}
