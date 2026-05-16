import Foundation
import UIKit

enum RewardedGateResult: Equatable {
    case proceed
    case adNotReady
    case userClosed
    case failed(reason: String)
}

@MainActor
struct RewardedGateCoordinator {
    let membership: Membership?

    func shouldProceedWithoutGate(
        unlockID: RewardedAdManager.UnlockID,
        rewardedManager: RewardedAdManager,
    ) -> Bool {
        !RewardedSessionGate.shouldShowGate(
            unlockID: unlockID,
            sessionUnlocks: rewardedManager.sessionUnlocks,
            isAdFree: membership?.adFreeBySolePromotion ?? false,
            isPro: membership?.proIsActive ?? false,
        )
    }

    func loadAd(rewardedManager: RewardedAdManager) {
        rewardedManager.loadIfNeeded(
            promotionStore: membership?.promotionStore,
            subscriptionStore: membership?.subscriptionStore,
        )
    }

    func presentGateAd(
        unlockID: RewardedAdManager.UnlockID,
        rewardedManager: RewardedAdManager,
        coordinator: FullscreenAdCoordinator,
        rootViewController: UIViewController?,
    ) async -> RewardedGateOutcome {
        if shouldProceedWithoutGate(unlockID: unlockID, rewardedManager: rewardedManager) {
            return RewardedGateOutcome(result: .proceed, failureReason: nil)
        }
        if !rewardedManager.isLoaded {
            loadAd(rewardedManager: rewardedManager)
            return RewardedGateOutcome(
                result: .adNotReady,
                failureReason: String(localized: "rewarded_gate_load_failed"),
            )
        }
        let outcome = await rewardedManager.presentForReward(
            unlockID,
            from: rootViewController,
            coordinator: coordinator,
            promotionStore: membership?.promotionStore,
            subscriptionStore: membership?.subscriptionStore,
        )
        return mapOutcome(outcome)
    }

    private func mapOutcome(_ outcome: RewardedAdManager.RewardOutcome) -> RewardedGateOutcome {
        switch outcome {
            case .granted:
                return RewardedGateOutcome(result: .proceed, failureReason: nil)

            case .userClosed:
                return RewardedGateOutcome(
                    result: .userClosed,
                    failureReason: String(localized: "rewarded_gate_failure_not_completed"),
                )

            case let .failed(reason):
                let formatted = String(
                    format: String(localized: "rewarded_gate_failure_show_failed_template"),
                    reason,
                )
                return RewardedGateOutcome(
                    result: .failed(reason: reason),
                    failureReason: formatted,
                )
        }
    }
}

struct RewardedGateOutcome: Equatable {
    let result: RewardedGateResult
    let failureReason: String?
}
