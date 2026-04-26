import Foundation
@testable import PairShot
import SwiftUI
import XCTest

/// Audit-B — `AppOpenScenePhaseGate.shouldPresent(previous:current:)`
/// is the second-tier guard that runs inside
/// `PairShotApp.handleScenePhaseChange(_:)` after the
/// already-bootstrapped check. It distinguishes a real foreground
/// re-entry (`.background → .active`) from a transient interruption
/// (`.inactive → .active`, e.g. dismissing a system alert / control
/// centre / phone call banner).
///
/// Forgetting this check would surface an App Open ad every time the
/// user pulled down Control Centre and tapped back on the app — a
/// terrible experience flagged repeatedly in App Store review.
final class AppOpenScenePhaseGateTests: XCTestCase {
    // MARK: - happy: real foreground re-entry triggers

    func testBackgroundToActiveTriggersPresentation() {
        XCTAssertTrue(
            AppOpenScenePhaseGate.shouldPresent(previous: .background, current: .active)
        )
    }

    // MARK: - edge: transient interruptions skip

    func testInactiveToActiveSkipsPresentation() {
        XCTAssertFalse(
            AppOpenScenePhaseGate.shouldPresent(previous: .inactive, current: .active),
            ".inactive → .active is a transient interruption (control centre / system alert)"
                + " — must NOT trigger an App Open ad"
        )
    }

    func testActiveToActiveDuplicateSkipsPresentation() {
        // SwiftUI may emit `.onChange` redundantly with the same
        // value — the gate must reject the duplicate so we don't
        // spam an ad on each redraw.
        XCTAssertFalse(
            AppOpenScenePhaseGate.shouldPresent(previous: .active, current: .active)
        )
    }

    // MARK: - edge: non-active current phase always skips

    func testCurrentBackgroundAlwaysSkipsRegardlessOfPrevious() {
        for previous in [ScenePhase.background, .active, .inactive] {
            XCTAssertFalse(
                AppOpenScenePhaseGate.shouldPresent(previous: previous, current: .background),
                "current=.background must always skip; got triggered with previous=\(previous)"
            )
        }
    }

    func testCurrentInactiveAlwaysSkips() {
        for previous in [ScenePhase.background, .active, .inactive] {
            XCTAssertFalse(
                AppOpenScenePhaseGate.shouldPresent(previous: previous, current: .inactive)
            )
        }
    }

    // MARK: - sanity: AppOpenAdGate symmetric cap is unchanged

    func testAppOpenAdGateAppliesSameCapAcrossInvocations() {
        // Audit-D removed the `coldStart` parameter entirely; the gate
        // now consults only `lastShownAt`. Pin the symmetry so a
        // future re-introduction of branching surfaces here.
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(AppOpenAdGate.defaultMinimumInterval - 1)
        let firstInvocation = AppOpenAdGate.shouldPresent(
            lastShownAt: last,
            now: now
        )
        let secondInvocation = AppOpenAdGate.shouldPresent(
            lastShownAt: last,
            now: now
        )
        XCTAssertEqual(
            firstInvocation,
            secondInvocation,
            "two invocations with the same inputs must agree (no branching on coldStart anymore)"
        )
        // And both should deny — we're 1s under the cap.
        XCTAssertFalse(firstInvocation)
    }
}
