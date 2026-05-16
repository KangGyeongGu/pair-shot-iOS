import Foundation
@testable import PairShot
import Testing

struct MembershipResolverTests {
    private static let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
    private static let near = now.addingTimeInterval(60 * 60 * 24 * 7)
    private static let far = now.addingTimeInterval(60 * 60 * 24 * 90)

    @Test
    func `Subscription only active → proIsActive true; adFree inherits via Pro`() {
        let inputs = MembershipInputs(
            subscriptionIsPro: true,
            subscriptionExpiresAt: Self.near,
            promotionProIsActive: false,
            promotionProExpiresAt: nil,
            promotionAdFreeIsActive: false,
            promotionAdFreeExpiresAt: nil,
        )

        #expect(MembershipResolver.proIsActive(inputs: inputs))
        #expect(MembershipResolver.proExpiresAt(inputs: inputs) == Self.near)
        #expect(MembershipResolver.adFreeIsActive(inputs: inputs))
    }

    @Test
    func `Pro promotion only → proIsActive true; adFree inherits via Pro`() {
        let inputs = MembershipInputs(
            subscriptionIsPro: false,
            subscriptionExpiresAt: nil,
            promotionProIsActive: true,
            promotionProExpiresAt: Self.near,
            promotionAdFreeIsActive: false,
            promotionAdFreeExpiresAt: nil,
        )

        #expect(MembershipResolver.proIsActive(inputs: inputs))
        #expect(MembershipResolver.proExpiresAt(inputs: inputs) == Self.near)
        #expect(MembershipResolver.adFreeIsActive(inputs: inputs))
    }

    @Test
    func `Ad-free promotion only → adFreeIsActive true; proIsActive false`() {
        let inputs = MembershipInputs(
            subscriptionIsPro: false,
            subscriptionExpiresAt: nil,
            promotionProIsActive: false,
            promotionProExpiresAt: nil,
            promotionAdFreeIsActive: true,
            promotionAdFreeExpiresAt: Self.near,
        )

        #expect(MembershipResolver.proIsActive(inputs: inputs) == false)
        #expect(MembershipResolver.proExpiresAt(inputs: inputs) == nil)
        #expect(MembershipResolver.adFreeIsActive(inputs: inputs))
        #expect(MembershipResolver.adFreeExpiresAt(inputs: inputs) == Self.near)
    }

    @Test
    func `Subscription + Pro promotion → max expiry wins`() {
        let inputs = MembershipInputs(
            subscriptionIsPro: true,
            subscriptionExpiresAt: Self.near,
            promotionProIsActive: true,
            promotionProExpiresAt: Self.far,
            promotionAdFreeIsActive: false,
            promotionAdFreeExpiresAt: nil,
        )

        #expect(MembershipResolver.proIsActive(inputs: inputs))
        #expect(MembershipResolver.proExpiresAt(inputs: inputs) == Self.far)
    }

    @Test
    func `Subscription + Ad-free promotion: pro from subscription, ad-free expiry from max(pro, adFree)`() {
        let inputs = MembershipInputs(
            subscriptionIsPro: true,
            subscriptionExpiresAt: Self.near,
            promotionProIsActive: false,
            promotionProExpiresAt: nil,
            promotionAdFreeIsActive: true,
            promotionAdFreeExpiresAt: Self.far,
        )

        #expect(MembershipResolver.proIsActive(inputs: inputs))
        #expect(MembershipResolver.adFreeIsActive(inputs: inputs))
        #expect(MembershipResolver.adFreeExpiresAt(inputs: inputs) == Self.far)
    }

    @Test
    func `Permanent promotion (nil expiresAt) → expiry resolves to nil = unlimited`() {
        let inputs = MembershipInputs(
            subscriptionIsPro: false,
            subscriptionExpiresAt: nil,
            promotionProIsActive: true,
            promotionProExpiresAt: nil,
            promotionAdFreeIsActive: false,
            promotionAdFreeExpiresAt: nil,
        )

        #expect(MembershipResolver.proIsActive(inputs: inputs))
        #expect(MembershipResolver.proExpiresAt(inputs: inputs) == nil)
    }

    @Test
    func `Permanent subscription wins over dated promotion`() {
        let inputs = MembershipInputs(
            subscriptionIsPro: true,
            subscriptionExpiresAt: nil,
            promotionProIsActive: true,
            promotionProExpiresAt: Self.near,
            promotionAdFreeIsActive: false,
            promotionAdFreeExpiresAt: nil,
        )

        #expect(MembershipResolver.proExpiresAt(inputs: inputs) == nil)
    }

    @Test
    func `Nothing active → proIsActive false, adFreeIsActive false`() {
        let inputs = MembershipInputs(
            subscriptionIsPro: false,
            subscriptionExpiresAt: nil,
            promotionProIsActive: false,
            promotionProExpiresAt: nil,
            promotionAdFreeIsActive: false,
            promotionAdFreeExpiresAt: nil,
        )

        #expect(MembershipResolver.proIsActive(inputs: inputs) == false)
        #expect(MembershipResolver.adFreeIsActive(inputs: inputs) == false)
    }
}
