import Foundation
import Observation

@MainActor
@Observable
final class Entitlement {
    let subscriptionStore: SubscriptionStore
    let adFreeStore: AdFreeStore

    var isPaidPro: Bool {
        subscriptionStore.isPro
    }

    var hasCouponAdFree: Bool {
        adFreeStore.isAdFree
    }

    var isAdSuppressed: Bool {
        isPaidPro || hasCouponAdFree
    }

    init(subscriptionStore: SubscriptionStore, adFreeStore: AdFreeStore) {
        self.subscriptionStore = subscriptionStore
        self.adFreeStore = adFreeStore
    }
}
