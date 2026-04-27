import Foundation

enum AdsConfig {
    static let productionPlaceholder = "INSERT_PRODUCTION_ID_HERE"

    enum TestUnitID {
        static let banner = "ca-app-pub-3940256099942544/2934735716"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
        static let native = "ca-app-pub-3940256099942544/3986624511"
        static let appOpen = "ca-app-pub-3940256099942544/5575463023"
    }

    enum InfoPlistKey {
        static let banner = "AdUnitID_Banner"
        static let interstitial = "AdUnitID_Interstitial"
        static let rewarded = "AdUnitID_Rewarded"
        static let native = "AdUnitID_Native"
        static let appOpen = "AdUnitID_AppOpen"
    }

    static var banner: String {
        resolve(testID: TestUnitID.banner, infoKey: InfoPlistKey.banner)
    }

    static var interstitial: String {
        resolve(testID: TestUnitID.interstitial, infoKey: InfoPlistKey.interstitial)
    }

    static var rewarded: String {
        resolve(testID: TestUnitID.rewarded, infoKey: InfoPlistKey.rewarded)
    }

    static var native: String {
        resolve(testID: TestUnitID.native, infoKey: InfoPlistKey.native)
    }

    static var appOpen: String {
        resolve(testID: TestUnitID.appOpen, infoKey: InfoPlistKey.appOpen)
    }

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
