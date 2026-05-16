import Foundation

@MainActor
enum AdSuppression {
    static func isSuppressed(
        promotionStore: PromotionStore?,
        subscriptionStore: SubscriptionStore?,
    ) -> Bool {
        let promotion = promotionStore?.adFreeIsActive ?? false
        let subscription = subscriptionStore?.isPro ?? false
        return promotion || subscription
    }

    static func isSuppressed(isAdFree: Bool, isPro: Bool) -> Bool {
        isAdFree || isPro
    }
}
