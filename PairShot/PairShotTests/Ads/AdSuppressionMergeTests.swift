import Foundation
@testable import PairShot
import Testing

@MainActor
struct AdSuppressionMergeTests {
    @Test("Both flags false → ads shown (suppression = false)")
    func bothFalseShowsAds() {
        #expect(AdSuppression.isSuppressed(isAdFree: false, isPro: false) == false)
    }

    @Test("Coupon active only → ads suppressed")
    func couponOnlySuppresses() {
        #expect(AdSuppression.isSuppressed(isAdFree: true, isPro: false) == true)
    }

    @Test("Pro subscription only → ads suppressed")
    func proOnlySuppresses() {
        #expect(AdSuppression.isSuppressed(isAdFree: false, isPro: true) == true)
    }

    @Test("Both coupon and Pro → ads suppressed")
    func bothActiveSuppresses() {
        #expect(AdSuppression.isSuppressed(isAdFree: true, isPro: true) == true)
    }

    @Test("BannerAdGate.shouldShow mirrors OR-suppression for all 4 cases")
    func bannerGateMatchesSuppression() {
        let cases: [(isAdFree: Bool, isPro: Bool, expected: Bool)] = [
            (false, false, true),
            (true, false, false),
            (false, true, false),
            (true, true, false),
        ]
        for input in cases {
            #expect(
                BannerAdGate.shouldShow(isAdFree: input.isAdFree, isPro: input.isPro) == input.expected
            )
        }
    }

    @Test("RewardedSessionGate.shouldShowGate suppresses gate when Pro is active")
    func rewardedGateRespectsPro() {
        let unlock: RewardedAdManager.UnlockID = .compositionSettings
        #expect(
            RewardedSessionGate.shouldShowGate(
                unlockID: unlock,
                sessionUnlocks: [],
                isAdFree: false,
                isPro: true
            ) == false
        )
        #expect(
            RewardedSessionGate.shouldShowGate(
                unlockID: unlock,
                sessionUnlocks: [],
                isAdFree: false,
                isPro: false
            ) == true
        )
        #expect(
            RewardedSessionGate.shouldShowGate(
                unlockID: unlock,
                sessionUnlocks: [],
                isAdFree: true,
                isPro: false
            ) == false
        )
    }
}
