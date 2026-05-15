import Foundation
@testable import PairShot
import Testing

struct PromotionRedemptionLinkTests {
    @Test("buildURL produces /redeem path with d= query parameter")
    func buildsExpectedRedeemURL() throws {
        let config = CouponApiConfig(baseUrl: "https://coupon.pairshot.app", timeoutSeconds: 10)
        let url = try #require(PromotionRedemptionLink.buildURL(config: config, deviceHash: "abc123"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.scheme == "https")
        #expect(components.host == "coupon.pairshot.app")
        #expect(components.path == "/redeem")
        #expect(components.queryItems == [URLQueryItem(name: "d", value: "abc123")])
    }

    @Test("buildURL returns nil when baseUrl is empty (config disabled)")
    func returnsNilForEmptyBaseUrl() {
        let config = CouponApiConfig(baseUrl: "", timeoutSeconds: 10)
        #expect(PromotionRedemptionLink.buildURL(config: config, deviceHash: "abc123") == nil)
    }

    @Test("buildURL percent-encodes special characters in deviceHash")
    func percentEncodesSpecialCharacters() throws {
        let config = CouponApiConfig(baseUrl: "https://coupon.pairshot.app", timeoutSeconds: 10)
        let hash = "a b+c/d?e&f=g"
        let url = try #require(PromotionRedemptionLink.buildURL(config: config, deviceHash: hash))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.queryItems == [URLQueryItem(name: "d", value: hash)])

        let rawQuery = try #require(components.percentEncodedQuery)
        #expect(rawQuery.contains("%26"))
        #expect(rawQuery.contains("%3D"))
    }

    @Test("buildURL preserves baseUrl path suffix when appending /redeem")
    func preservesBaseUrlSuffixVerbatim() throws {
        let config = CouponApiConfig(baseUrl: "https://coupon.pairshot.app/v2", timeoutSeconds: 10)
        let url = try #require(PromotionRedemptionLink.buildURL(config: config, deviceHash: "x"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/v2/redeem")
    }

    @Test("buildURL with non-ASCII deviceHash percent-encodes via URLQueryItem")
    func percentEncodesNonAsciiHash() throws {
        let config = CouponApiConfig(baseUrl: "https://coupon.pairshot.app", timeoutSeconds: 10)
        let hash = "한글"
        let url = try #require(PromotionRedemptionLink.buildURL(config: config, deviceHash: hash))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.queryItems == [URLQueryItem(name: "d", value: hash)])
        let rawQuery = try #require(components.percentEncodedQuery)
        #expect(rawQuery.contains("%"))
        #expect(rawQuery.hasPrefix("d="))
    }
}
