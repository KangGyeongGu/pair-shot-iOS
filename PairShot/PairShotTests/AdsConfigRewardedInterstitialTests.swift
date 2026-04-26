import Foundation
@testable import PairShot
import XCTest

/// Audit-B — verifies the new `AdUnitID_RewardedInterstitial` Info.plist
/// key + xcconfig surface introduced for parity with the other four
/// ad-unit ids (banner / interstitial / rewarded / native / app open).
///
/// Locks down:
/// - The Info.plist key constant matches the literal string declared
///   in `PairShot/Info.plist` so a future rename surfaces as a
///   compile-or-test failure rather than a silent missing-key fallback.
/// - The DEBUG short-circuit returns Google's official rewarded-
///   interstitial test unit id (matches the other DEBUG accessors).
/// - The `resolveRelease(...)` placeholder + nil + empty branches
///   fall back to the test id, so an un-edited xcconfig cannot ship
///   the literal `INSERT_PRODUCTION_ID_HERE` to the AdMob SDK.
final class AdsConfigRewardedInterstitialTests: XCTestCase {
    // MARK: - constants

    func testInfoPlistKeyConstantMatchesPlistLiteral() {
        // The string MUST equal the Info.plist key. If the xcconfig key
        // is renamed, the lookup falls back to the test id silently —
        // this assertion catches the drift.
        XCTAssertEqual(
            AdsConfig.InfoPlistKey.rewardedInterstitial,
            "AdUnitID_RewardedInterstitial"
        )
    }

    func testTestUnitIDMatchesGoogleOfficialValue() {
        // Source: https://developers.google.com/admob/ios/test-ads
        XCTAssertEqual(
            AdsConfig.TestUnitID.rewardedInterstitial,
            "ca-app-pub-3940256099942544/6978759866"
        )
    }

    // MARK: - DEBUG short-circuit

    func testDebugBuildReturnsTestUnitForRewardedInterstitial() {
        #if DEBUG
            XCTAssertEqual(
                AdsConfig.rewardedInterstitial,
                AdsConfig.TestUnitID.rewardedInterstitial
            )
        #endif
    }

    // MARK: - RELEASE fallback semantics

    func testRealProductionIDIsReturnedWhenPresent() {
        let realID = "ca-app-pub-1234567890123456/9876543210"
        let result = AdsConfig.resolveRelease(
            testID: AdsConfig.TestUnitID.rewardedInterstitial,
            bundleValue: realID
        )
        XCTAssertEqual(result, realID)
    }

    func testProductionPlaceholderFallsBackToTestID() {
        let result = AdsConfig.resolveRelease(
            testID: AdsConfig.TestUnitID.rewardedInterstitial,
            bundleValue: AdsConfig.productionPlaceholder
        )
        XCTAssertEqual(result, AdsConfig.TestUnitID.rewardedInterstitial)
    }

    func testNilBundleValueFallsBackToTestID() {
        let result = AdsConfig.resolveRelease(
            testID: AdsConfig.TestUnitID.rewardedInterstitial,
            bundleValue: nil
        )
        XCTAssertEqual(result, AdsConfig.TestUnitID.rewardedInterstitial)
    }

    func testEmptyBundleValueFallsBackToTestID() {
        let result = AdsConfig.resolveRelease(
            testID: AdsConfig.TestUnitID.rewardedInterstitial,
            bundleValue: ""
        )
        XCTAssertEqual(result, AdsConfig.TestUnitID.rewardedInterstitial)
    }
}
