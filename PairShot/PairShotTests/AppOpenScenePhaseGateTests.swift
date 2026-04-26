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

    func testColdStartArgumentDoesNotChangeAppOpenAdGateBehaviour() {
        // Audit-B simplified `AppOpenAdGate.shouldPresent(...)` to
        // ignore `coldStart` because both paths share the same cap.
        // Pin the symmetry so a future re-introduction of branching
        // surfaces here.
        let last = Date(timeIntervalSince1970: 1000)
        let now = last.addingTimeInterval(AppOpenAdGate.defaultMinimumInterval - 1)
        let cold = AppOpenAdGate.shouldPresent(
            coldStart: true,
            lastShownAt: last,
            now: now
        )
        let warm = AppOpenAdGate.shouldPresent(
            coldStart: false,
            lastShownAt: last,
            now: now
        )
        XCTAssertEqual(
            cold,
            warm,
            "cold-start and foreground-return must share the same cap policy"
        )
    }
}
