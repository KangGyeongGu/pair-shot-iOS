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
