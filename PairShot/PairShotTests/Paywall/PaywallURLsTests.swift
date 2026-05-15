import Foundation
@testable import PairShot
import Testing

struct PaywallURLsTests {
    @Test("privacy URL points to pairshot.kangkyeonggu.com host over https")
    func privacyURLIsValidRemote() {
        let url = PaywallURLs.privacy
        #expect(url.isFileURL == false)
        #expect(url.scheme == "https")
        #expect(url.host == "pairshot.kangkyeonggu.com")
        #expect(url.path == "/privacy" || url.path == "/privacy/en")
    }

    @Test("terms URL points to pairshot.kangkyeonggu.com host over https")
    func termsURLIsValidRemote() {
        let url = PaywallURLs.terms
        #expect(url.isFileURL == false)
        #expect(url.scheme == "https")
        #expect(url.host == "pairshot.kangkyeonggu.com")
        #expect(url.path == "/terms" || url.path == "/terms/en")
    }

    @Test("privacy and terms URLs are distinct")
    func privacyAndTermsAreDistinct() {
        #expect(PaywallURLs.privacy != PaywallURLs.terms)
    }
}
