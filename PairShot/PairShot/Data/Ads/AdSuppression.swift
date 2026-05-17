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

    static func isSuppressed(
        membership: Membership,
        tutorialCoordinator: TutorialCoordinator? = nil,
    ) -> Bool {
        isSuppressed(
            isAdFree: membership.adFreeIsActive,
            isPro: membership.proIsActive,
            tutorialActive: tutorialCoordinator?.isActive ?? false,
        )
    }

    static func isSuppressed(
        isAdFree: Bool,
        isPro: Bool,
        tutorialActive: Bool = false,
    ) -> Bool {
        isAdFree || isPro || tutorialActive
    }
}
