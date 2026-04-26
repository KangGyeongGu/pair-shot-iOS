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
}
