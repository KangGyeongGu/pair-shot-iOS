import Foundation
@testable import PairShot
import XCTest

/// P6.1 — DEBUG returns Google's official test unit ids; RELEASE uses
/// Info.plist with a test-id fallback when the key is absent.
final class AdsConfigTests: XCTestCase {
    // MARK: - happy

    func testTestUnitIDsMatchGoogleOfficialValues() {
        // The literal values come from
        // https://developers.google.com/admob/ios/test-ads — pinning them
        // protects against accidental edits that might let production-like
        // ids leak into DEBUG builds.
        XCTAssertEqual(
            AdsConfig.TestUnitID.banner,
            "ca-app-pub-3940256099942544/2934735716"
        )
        XCTAssertEqual(
            AdsConfig.TestUnitID.interstitial,
            "ca-app-pub-3940256099942544/4411468910"
        )
        XCTAssertEqual(
            AdsConfig.TestUnitID.rewarded,
            "ca-app-pub-3940256099942544/1712485313"
        )
        XCTAssertEqual(
            AdsConfig.TestUnitID.appOpen,
            "ca-app-pub-3940256099942544/5662855259"
        )
    }

    func testDebugBuildReturnsTestUnitForBanner() {
        // In the DEBUG configuration this XCTest binary runs under, the
        // computed accessor must be the test id regardless of what is in
        // Info.plist. (RELEASE-only fallback semantics are exercised via
        // the `bundle:` overload below.)
        #if DEBUG
            XCTAssertEqual(AdsConfig.banner, AdsConfig.TestUnitID.banner)
            XCTAssertEqual(AdsConfig.interstitial, AdsConfig.TestUnitID.interstitial)
            XCTAssertEqual(AdsConfig.rewarded, AdsConfig.TestUnitID.rewarded)
            XCTAssertEqual(AdsConfig.appOpen, AdsConfig.TestUnitID.appOpen)
            XCTAssertEqual(AdsConfig.native, AdsConfig.TestUnitID.native)
        #endif
    }

    // MARK: - edge

    func testResolveFallsBackToTestIDWhenInfoPlistKeyMissing() {
        // `Bundle(for:)` of an XCTestCase has no AdUnitID_* keys, so the
        // resolve seam must fall through to the test id even in RELEASE.
        let result = AdsConfig.resolve(
            testID: "TEST",
            infoKey: "AdUnitID_DefinitelyMissingKey",
            bundle: Bundle(for: AdsConfigTests.self)
        )
        XCTAssertEqual(result, "TEST")
    }

    func testInfoPlistKeyConstantsAreNonEmpty() {
        XCTAssertFalse(AdsConfig.InfoPlistKey.banner.isEmpty)
        XCTAssertFalse(AdsConfig.InfoPlistKey.interstitial.isEmpty)
        XCTAssertFalse(AdsConfig.InfoPlistKey.rewarded.isEmpty)
        XCTAssertFalse(AdsConfig.InfoPlistKey.appOpen.isEmpty)
        XCTAssertFalse(AdsConfig.InfoPlistKey.native.isEmpty)
    }
}
