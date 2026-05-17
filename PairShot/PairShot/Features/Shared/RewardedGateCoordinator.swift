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
    let tutorialCoordinator: TutorialCoordinator?

    func shouldProceedWithoutGate(
        unlockID: RewardedAdManager.UnlockID,
        rewardedManager: RewardedAdManager,
    ) -> Bool {
        guard let membership else { return true }
        return !RewardedSessionGate.shouldShowGate(
            unlockID: unlockID,
            sessionUnlocks: rewardedManager.sessionUnlocks,
            membership: membership,
            tutorialCoordinator: tutorialCoordinator,
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
                if reason == "not-loaded" {
                    return RewardedGateOutcome(
                        result: .adNotReady,
                        failureReason: String(localized: "rewarded_gate_load_failed"),
                    )
                }
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
