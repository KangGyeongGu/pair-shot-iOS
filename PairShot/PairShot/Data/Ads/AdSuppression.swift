import Foundation

@MainActor
enum AdSuppression {
    static func isSuppressed(
        adFreeStore: AdFreeStore?,
        subscriptionStore: SubscriptionStore?
    ) -> Bool {
        let coupon = adFreeStore?.isAdFree ?? false
        let subscription = subscriptionStore?.isPro ?? false
        return coupon || subscription
    }

    static func isSuppressed(isAdFree: Bool, isPro: Bool) -> Bool {
        isAdFree || isPro
    }
}
