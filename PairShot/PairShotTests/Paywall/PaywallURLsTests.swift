import Foundation
@testable import PairShot
import Testing

struct PaywallURLsTests {
    @Test
    func `privacy URL points to pairshot.kangkyeonggu.com host over https`() {
        let url = PaywallURLs.privacy
        #expect(url.isFileURL == false)
        #expect(url.scheme == "https")
        #expect(url.host == "pairshot.kangkyeonggu.com")
        #expect(url.path == "/privacy" || url.path == "/privacy/en")
    }

    @Test
    func `terms URL points to pairshot.kangkyeonggu.com host over https`() {
        let url = PaywallURLs.terms
        #expect(url.isFileURL == false)
        #expect(url.scheme == "https")
        #expect(url.host == "pairshot.kangkyeonggu.com")
        #expect(url.path == "/terms" || url.path == "/terms/en")
    }

    @Test
    func `privacy and terms URLs are distinct`() {
        #expect(PaywallURLs.privacy != PaywallURLs.terms)
    }
}
