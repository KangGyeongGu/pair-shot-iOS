import Foundation

@MainActor
enum AdSuppression {
    static func isSuppressed(
        promotionStore: PromotionStore?,
        subscriptionStore: SubscriptionStore?,
        tutorialCoordinator: TutorialCoordinator? = nil,
    ) -> Bool {
        let promotion = promotionStore?.adFreeIsActive ?? false
        let subscription = subscriptionStore?.isPro ?? false
        let tutorial = tutorialCoordinator?.isActive ?? false
        return promotion || subscription || tutorial
    }

    static func isSuppressed(isAdFree: Bool, isPro: Bool) -> Bool {
        isAdFree || isPro
    }
}
