import Foundation

/// Centralised AdMob unit-id resolution.
///
/// In `DEBUG` builds we always return Google's official **test** unit ids
/// (https://developers.google.com/admob/ios/test-ads) so engineers never
/// accidentally serve real ads while developing. In `RELEASE` builds we
/// look the value up from the app's `Info.plist`; if the key is missing
/// **or still contains the xcconfig placeholder string** (see P10.5
/// `Config/Release.xcconfig`), we fall back to the same test id rather
/// than crashing or returning an empty string. This keeps the app
/// shippable for internal builds and the lookup path debuggable while
/// still emitting an obvious test-ad banner so QA notices the missing
/// production id.
///
/// All members are pure value lookups — no SDK calls — so this file is
/// safe to import from anywhere and from tests.
enum AdsConfig {
    /// Sentinel string used in `Config/Release.xcconfig` for ad-unit ids
    /// that haven't been replaced with real production values yet. When
    /// `Bundle.main.object(forInfoDictionaryKey:)` returns this string,
    /// we treat the key as effectively absent and fall back to the test
    /// id. Keeping the sentinel as a public constant lets the unit
    /// tests assert the fallback path without duplicating the literal.
    static let productionPlaceholder = "INSERT_PRODUCTION_ID_HERE"

    /// Google AdMob official test unit ids — these always serve a test ad.
    /// Source: https://developers.google.com/admob/ios/test-ads
    enum TestUnitID {
        static let banner = "ca-app-pub-3940256099942544/2934735716"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
        static let rewardedInterstitial = "ca-app-pub-3940256099942544/6978759866"
        static let native = "ca-app-pub-3940256099942544/3986624511"
        static let appOpen = "ca-app-pub-3940256099942544/5662855259"
    }

    /// Info.plist keys an integrator can set (via xcconfig at build time)
    /// to override the test ids in RELEASE.
    enum InfoPlistKey {
        static let banner = "AdUnitID_Banner"
        static let interstitial = "AdUnitID_Interstitial"
        static let rewarded = "AdUnitID_Rewarded"
        static let rewardedInterstitial = "AdUnitID_RewardedInterstitial"
        static let native = "AdUnitID_Native"
        static let appOpen = "AdUnitID_AppOpen"
    }

    /// Banner ad unit id — DEBUG returns the test unit, RELEASE looks up
    /// the Info.plist override and falls back to the test unit.
    static var banner: String {
        resolve(testID: TestUnitID.banner, infoKey: InfoPlistKey.banner)
    }

    static var interstitial: String {
        resolve(testID: TestUnitID.interstitial, infoKey: InfoPlistKey.interstitial)
    }

    static var rewarded: String {
        resolve(testID: TestUnitID.rewarded, infoKey: InfoPlistKey.rewarded)
    }

    static var rewardedInterstitial: String {
        resolve(
            testID: TestUnitID.rewardedInterstitial,
            infoKey: InfoPlistKey.rewardedInterstitial
        )
    }

    static var native: String {
        resolve(testID: TestUnitID.native, infoKey: InfoPlistKey.native)
    }

    static var appOpen: String {
        resolve(testID: TestUnitID.appOpen, infoKey: InfoPlistKey.appOpen)
    }

    /// Test seam: resolve a unit id given an explicit bundle. Tests use
    /// this overload to assert RELEASE fallback semantics without having
    /// to mutate the main bundle's Info.plist.
    ///
    /// The method intentionally treats the production placeholder
    /// sentinel as "absent" so an un-edited `Release.xcconfig` doesn't
    /// ship literal text into a `GADBannerView` ad-unit field (which
    /// would silently fail to load instead of obviously serving a test
    /// ad). The behaviour holds in both DEBUG and RELEASE — DEBUG never
    /// reads the bundle anyway, but the explicit guard keeps the
    /// branch order obvious.
    static func resolve(testID: String, infoKey: String, bundle: Bundle = .main) -> String {
        #if DEBUG
            return testID
        #else
            if let value = bundle.object(forInfoDictionaryKey: infoKey) as? String,
               !value.isEmpty,
               value != productionPlaceholder
            {
                return value
            }
            return testID
        #endif
    }

    /// Pure-function variant that ignores the build configuration. Used
    /// by ``AdsConfigReleaseLookupTests`` to exercise the
    /// placeholder-detection branch the live `resolve(...)` would skip
    /// when the test binary is compiled DEBUG. The behaviour mirrors
    /// the RELEASE arm of `resolve(testID:infoKey:bundle:)` exactly so
    /// the two stay in lock-step.
    static func resolveRelease(
        testID: String,
        bundleValue: String?
    ) -> String {
        if let value = bundleValue,
           !value.isEmpty,
           value != productionPlaceholder
        {
            return value
        }
        return testID
    }
}
