@MainActor
enum AdSuppression {
    static func isSuppressed(
        promotionStore: PromotionStore?,
        subscriptionStore: SubscriptionStore?,
        tutorialCoordinator: TutorialCoordinator? = nil,
    ) -> Bool {
        let promotionAdFree = promotionStore?.adFreeIsActive ?? false
        let promotionPro = promotionStore?.proIsActive ?? false
        let subscriptionPro = subscriptionStore?.isPro ?? false
        let tutorial = tutorialCoordinator?.isActive ?? false
        return promotionAdFree || promotionPro || subscriptionPro || tutorial
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

    static func isLoadSuppressed(
        promotionStore: PromotionStore?,
        subscriptionStore: SubscriptionStore?,
    ) -> Bool {
        let promotionAdFree = promotionStore?.adFreeIsActive ?? false
        let promotionPro = promotionStore?.proIsActive ?? false
        let subscriptionPro = subscriptionStore?.isPro ?? false
        return promotionAdFree || promotionPro || subscriptionPro
    }
}
