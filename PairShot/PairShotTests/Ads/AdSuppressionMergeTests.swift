import Foundation
@testable import PairShot
import Testing

@MainActor
struct AdSuppressionMergeTests {
    @Test
    func `Both flags false → ads shown (suppression = false)`() {
        #expect(AdSuppression.isSuppressed(isAdFree: false, isPro: false) == false)
    }

    @Test
    func `Coupon active only → ads suppressed`() {
        #expect(AdSuppression.isSuppressed(isAdFree: true, isPro: false) == true)
    }

    @Test
    func `Pro subscription only → ads suppressed`() {
        #expect(AdSuppression.isSuppressed(isAdFree: false, isPro: true) == true)
    }

    @Test
    func `Both coupon and Pro → ads suppressed`() {
        #expect(AdSuppression.isSuppressed(isAdFree: true, isPro: true) == true)
    }

    @Test
    func `BannerAdGate.shouldShow mirrors OR-suppression for all 4 cases`() {
        let cases: [(isAdFree: Bool, isPro: Bool, expected: Bool)] = [
            (false, false, true),
            (true, false, false),
            (false, true, false),
            (true, true, false),
        ]
        for input in cases {
            #expect(
                BannerAdGate.shouldShow(isAdFree: input.isAdFree, isPro: input.isPro) == input.expected,
            )
        }
    }

    @Test
    func `튜토리얼 비활성 + 둘 다 false → 기존과 동일하게 suppression false`() {
        let coord = TutorialCoordinator()
        #expect(
            AdSuppression.isSuppressed(
                promotionStore: nil,
                subscriptionStore: nil,
                tutorialCoordinator: coord,
            ) == false,
        )
    }

    @Test
    func `튜토리얼 활성 + 둘 다 false → suppression true (신규 가드)`() {
        let coord = TutorialCoordinator()
        coord.start()
        #expect(
            AdSuppression.isSuppressed(
                promotionStore: nil,
                subscriptionStore: nil,
                tutorialCoordinator: coord,
            ) == true,
        )
    }

    @Test
    func `튜토리얼 done 상태 → isActive false 로 간주되어 suppression false`() {
        let coord = TutorialCoordinator()
        coord.complete()
        #expect(
            AdSuppression.isSuppressed(
                promotionStore: nil,
                subscriptionStore: nil,
                tutorialCoordinator: coord,
            ) == false,
        )
    }

    @Test
    func `튜토리얼 nil 전달 시 기존 시그니처와 동일 결과`() {
        #expect(
            AdSuppression.isSuppressed(
                promotionStore: nil,
                subscriptionStore: nil,
                tutorialCoordinator: nil,
            ) == false,
        )
    }

    @Test
    func `RewardedSessionGate.shouldShowGate suppresses gate when Pro is active`() {
        let unlock: RewardedAdManager.UnlockID = .compositionSettings
        #expect(
            RewardedSessionGate.shouldShowGate(
                unlockID: unlock,
                sessionUnlocks: [],
                isAdFree: false,
                isPro: true,
            ) == false,
        )
        #expect(
            RewardedSessionGate.shouldShowGate(
                unlockID: unlock,
                sessionUnlocks: [],
                isAdFree: false,
                isPro: false,
            ) == true,
        )
        #expect(
            RewardedSessionGate.shouldShowGate(
                unlockID: unlock,
                sessionUnlocks: [],
                isAdFree: true,
                isPro: false,
            ) == false,
        )
    }
}
