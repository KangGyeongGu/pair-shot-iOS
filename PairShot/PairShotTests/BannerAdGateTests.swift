import Foundation
@testable import PairShot
import XCTest

/// P6.5 — `BannerAdGate.shouldShow(isAdFree:)` is the trivial AdFree
/// guard the banner surface uses. Even though the rule is one line, we
/// pin the behaviour with tests so a reviewer can't silently invert the
/// sense (showing banners to ad-free users is a regression by CLAUDE.md
/// core principle 7).
final class BannerAdGateTests: XCTestCase {
    func testNonAdFreeUserSeesBanner() {
        XCTAssertTrue(BannerAdGate.shouldShow(isAdFree: false))
    }

    func testAdFreeUserDoesNotSeeBanner() {
        XCTAssertFalse(BannerAdGate.shouldShow(isAdFree: true))
    }

    func testGateIsPureAndIdempotent() {
        // Multiple invocations must return identical results — no
        // hidden state. This catches a refactor that accidentally
        // memoises or threads the call through a stateful service.
        for _ in 0 ..< 5 {
            XCTAssertTrue(BannerAdGate.shouldShow(isAdFree: false))
            XCTAssertFalse(BannerAdGate.shouldShow(isAdFree: true))
        }
    }

    // MARK: - Audit-D — BannerAdSize.shouldReload policy

    func testFirstMeasurementTriggersReload() {
        XCTAssertTrue(
            BannerAdSize.shouldReload(previous: 0, current: 320),
            "first non-zero width must trigger an adSize update"
        )
    }

    func testFirstMeasurementOfZeroDoesNotReload() {
        XCTAssertFalse(
            BannerAdSize.shouldReload(previous: 0, current: 0),
            "zero width with no prior measurement should be a no-op"
        )
    }

    func testIdenticalWidthSkipsReload() {
        XCTAssertFalse(
            BannerAdSize.shouldReload(previous: 414, current: 414),
            "stable width must not churn the SDK"
        )
    }

    func testWidthChangeBeyondThresholdReloads() {
        XCTAssertTrue(
            BannerAdSize.shouldReload(previous: 320, current: 414),
            "rotation portrait → landscape must update the adaptive size"
        )
    }

    func testSubPixelChangeSkipsReload() {
        // SwiftUI may report layout deltas under the hysteresis
        // threshold during animations — those must not reload.
        XCTAssertFalse(
            BannerAdSize.shouldReload(previous: 414, current: 414.4),
            "sub-pixel jitter must stay below the reload threshold"
        )
    }

    func testFallbackWidthIsThreeTwenty() {
        XCTAssertEqual(BannerAdSize.fallbackWidth, 320)
    }
}
