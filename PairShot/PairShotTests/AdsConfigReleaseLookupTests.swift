import Foundation
@testable import PairShot
import XCTest

/// P10.5 — RELEASE-path Bundle lookup semantics.
///
/// The live `AdsConfig.resolve(testID:infoKey:bundle:)` short-circuits
/// to the test id when the test binary is compiled DEBUG (every
/// `xcodebuild test` invocation). To still exercise the placeholder vs
/// real-id branch logic, we route through the pure
/// `resolveRelease(testID:bundleValue:)` overload that mirrors the
/// RELEASE arm exactly.
///
/// These tests guard the contract for `Config/Release.xcconfig`: an
/// un-edited xcconfig (`INSERT_PRODUCTION_ID_HERE`) must NOT be
/// returned to the AdMob SDK, otherwise we'd quietly upload a build
/// that fails to load any ads.
final class AdsConfigReleaseLookupTests: XCTestCase {
    // MARK: - happy: real production id is returned

    func testRealProductionIDIsReturnedWhenPresent() {
        let result = AdsConfig.resolveRelease(
            testID: AdsConfig.TestUnitID.banner,
            bundleValue: "ca-app-pub-1234567890123456/1234567890"
        )
        XCTAssertEqual(result, "ca-app-pub-1234567890123456/1234567890")
    }

    func testRealProductionIDDifferentFromTestID() {
        // The fallback test id and the supplied real id must NOT be
        // equal — otherwise the assertion above is trivially true.
        let realID = "ca-app-pub-9999999999999999/9999999999"
        XCTAssertNotEqual(realID, AdsConfig.TestUnitID.banner)
        let result = AdsConfig.resolveRelease(
            testID: AdsConfig.TestUnitID.banner,
            bundleValue: realID
        )
        XCTAssertEqual(result, realID)
    }

    // MARK: - edge: placeholder / nil / empty all fall back

    func testProductionPlaceholderFallsBackToTestID() {
        // `INSERT_PRODUCTION_ID_HERE` is the literal string in
        // `Release.xcconfig`. If we ever forget to edit the xcconfig,
        // the SDK must still receive a valid (test) unit id rather
        // than the literal sentinel.
        let result = AdsConfig.resolveRelease(
            testID: AdsConfig.TestUnitID.banner,
            bundleValue: AdsConfig.productionPlaceholder
        )
        XCTAssertEqual(result, AdsConfig.TestUnitID.banner)
    }

    func testNilBundleValueFallsBackToTestID() {
        // Bundle.object(forInfoDictionaryKey:) returns nil for missing
        // keys (or when the value isn't a String). Both paths must
        // funnel into the test-id fallback.
        let result = AdsConfig.resolveRelease(
            testID: AdsConfig.TestUnitID.interstitial,
            bundleValue: nil
        )
        XCTAssertEqual(result, AdsConfig.TestUnitID.interstitial)
    }

    func testEmptyBundleValueFallsBackToTestID() {
        let result = AdsConfig.resolveRelease(
            testID: AdsConfig.TestUnitID.rewarded,
            bundleValue: ""
        )
        XCTAssertEqual(result, AdsConfig.TestUnitID.rewarded)
    }

    func testProductionPlaceholderConstantIsExposed() {
        // The constant must stay public so xcconfig templating tools
        // (and these tests) can rely on the same literal.
        XCTAssertEqual(AdsConfig.productionPlaceholder, "INSERT_PRODUCTION_ID_HERE")
        XCTAssertFalse(AdsConfig.productionPlaceholder.isEmpty)
    }
}
