import Foundation

struct MembershipInputs: Equatable {
    let subscriptionIsPro: Bool
    let subscriptionExpiresAt: Date?
    let promotionProIsActive: Bool
    let promotionProExpiresAt: Date?
    let promotionAdFreeIsActive: Bool
    let promotionAdFreeExpiresAt: Date?
}

@MainActor
enum MembershipResolver {
    static func proIsActive(
        subscription: SubscriptionStore,
        promotion: PromotionStore
    ) -> Bool {
        proIsActive(inputs: snapshot(subscription: subscription, promotion: promotion))
    }

    static func proExpiresAt(
        subscription: SubscriptionStore,
        promotion: PromotionStore
    ) -> Date? {
        proExpiresAt(inputs: snapshot(subscription: subscription, promotion: promotion))
    }

    static func adFreeIsActive(
        subscription: SubscriptionStore,
        promotion: PromotionStore
    ) -> Bool {
        adFreeIsActive(inputs: snapshot(subscription: subscription, promotion: promotion))
    }

    static func adFreeExpiresAt(
        subscription: SubscriptionStore,
        promotion: PromotionStore
    ) -> Date? {
        adFreeExpiresAt(inputs: snapshot(subscription: subscription, promotion: promotion))
    }

    private static func snapshot(
        subscription: SubscriptionStore,
        promotion: PromotionStore
    ) -> MembershipInputs {
        MembershipInputs(
            subscriptionIsPro: subscription.isPro,
            subscriptionExpiresAt: subscription.proExpiresAt,
            promotionProIsActive: promotion.proIsActive,
            promotionProExpiresAt: promotion.proExpiresAt,
            promotionAdFreeIsActive: promotion.adFreeIsActive,
            promotionAdFreeExpiresAt: promotion.adFreeExpiresAt
        )
    }
}

extension MembershipResolver {
    nonisolated static func proIsActive(inputs: MembershipInputs) -> Bool {
        inputs.subscriptionIsPro || inputs.promotionProIsActive
    }

    nonisolated static func proExpiresAt(inputs: MembershipInputs) -> Date? {
        latestExpiry(
            subscriptionActive: inputs.subscriptionIsPro,
            subscriptionExpiry: inputs.subscriptionExpiresAt,
            promotionActive: inputs.promotionProIsActive,
            promotionExpiry: inputs.promotionProExpiresAt
        )
    }

    nonisolated static func adFreeIsActive(inputs: MembershipInputs) -> Bool {
        proIsActive(inputs: inputs) || inputs.promotionAdFreeIsActive
    }

    nonisolated static func adFreeExpiresAt(inputs: MembershipInputs) -> Date? {
        let proActive = proIsActive(inputs: inputs)
        let proExpiry = proExpiresAt(inputs: inputs)
        return latestExpiry(
            subscriptionActive: proActive,
            subscriptionExpiry: proExpiry,
            promotionActive: inputs.promotionAdFreeIsActive,
            promotionExpiry: inputs.promotionAdFreeExpiresAt
        )
    }

    private nonisolated static func latestExpiry(
        subscriptionActive: Bool,
        subscriptionExpiry: Date?,
        promotionActive: Bool,
        promotionExpiry: Date?
    ) -> Date? {
        let subValue = subscriptionActive ? subscriptionExpiry : nil
        let promoValue = promotionActive ? promotionExpiry : nil
        if subscriptionActive, subValue == nil { return nil }
        if promotionActive, promoValue == nil { return nil }
        switch (subValue, promoValue) {
            case let (lhs?, rhs?): return max(lhs, rhs)
            case let (lhs?, nil): return lhs
            case let (nil, rhs?): return rhs
            case (nil, nil): return nil
        }
    }
}
