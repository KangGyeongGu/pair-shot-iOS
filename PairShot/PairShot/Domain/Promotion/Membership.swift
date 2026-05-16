import Foundation
import Observation

@MainActor
@Observable
final class Membership {
    let subscriptionStore: SubscriptionStore
    let promotionStore: PromotionStore

    var proIsActive: Bool {
        MembershipResolver.proIsActive(
            subscription: subscriptionStore,
            promotion: promotionStore,
        )
    }

    var proExpiresAt: Date? {
        MembershipResolver.proExpiresAt(
            subscription: subscriptionStore,
            promotion: promotionStore,
        )
    }

    var adFreeIsActive: Bool {
        MembershipResolver.adFreeIsActive(
            subscription: subscriptionStore,
            promotion: promotionStore,
        )
    }

    var adFreeExpiresAt: Date? {
        MembershipResolver.adFreeExpiresAt(
            subscription: subscriptionStore,
            promotion: promotionStore,
        )
    }

    var adFreeBySolePromotion: Bool {
        adFreeIsActive && !proIsActive
    }

    init(subscriptionStore: SubscriptionStore, promotionStore: PromotionStore) {
        self.subscriptionStore = subscriptionStore
        self.promotionStore = promotionStore
    }
}
