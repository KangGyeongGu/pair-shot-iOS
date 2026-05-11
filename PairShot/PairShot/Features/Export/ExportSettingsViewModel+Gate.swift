import Foundation
import UIKit

extension ExportSettingsViewModel {
    func requestWatermarkGate(rewardedManager: RewardedAdManager) -> Bool {
        requestGate(
            unlockID: .watermarkSettings,
            rewardedManager: rewardedManager,
            dialogFlag: \.showWatermarkGateDialog
        )
    }

    func requestCombineGate(rewardedManager: RewardedAdManager) -> Bool {
        requestGate(
            unlockID: .compositionSettings,
            rewardedManager: rewardedManager,
            dialogFlag: \.showCombineGateDialog
        )
    }

    func confirmWatermarkGateAd(
        rewardedManager: RewardedAdManager,
        coordinator: FullscreenAdCoordinator,
        rootViewController: UIViewController?
    ) async -> GateResult {
        await presentGateAd(
            unlockID: .watermarkSettings,
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: rootViewController
        )
    }

    func confirmCombineGateAd(
        rewardedManager: RewardedAdManager,
        coordinator: FullscreenAdCoordinator,
        rootViewController: UIViewController?
    ) async -> GateResult {
        await presentGateAd(
            unlockID: .compositionSettings,
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: rootViewController
        )
    }

    func requestGate(
        unlockID: RewardedAdManager.UnlockID,
        rewardedManager: RewardedAdManager,
        dialogFlag: ReferenceWritableKeyPath<ExportSettingsViewModel, Bool>
    ) -> Bool {
        lastGateFailureReason = nil
        if !RewardedSessionGate.shouldShowGate(
            unlockID: unlockID,
            sessionUnlocks: rewardedManager.sessionUnlocks,
            isAdFree: adFreeStore?.isAdFree ?? false
        ) {
            return true
        }
        rewardedManager.loadIfNeeded(adFreeStore: adFreeStore)
        self[keyPath: dialogFlag] = true
        return false
    }

    func presentGateAd(
        unlockID: RewardedAdManager.UnlockID,
        rewardedManager: RewardedAdManager,
        coordinator: FullscreenAdCoordinator,
        rootViewController: UIViewController?
    ) async -> GateResult {
        lastGateFailureReason = nil
        if !RewardedSessionGate.shouldShowGate(
            unlockID: unlockID,
            sessionUnlocks: rewardedManager.sessionUnlocks,
            isAdFree: adFreeStore?.isAdFree ?? false
        ) {
            return .proceed
        }
        if !rewardedManager.isLoaded {
            rewardedManager.loadIfNeeded(adFreeStore: adFreeStore)
            lastGateFailureReason = String(localized: "rewarded_gate_load_failed")
            return .adNotReady
        }
        let outcome = await rewardedManager.presentForReward(
            unlockID,
            from: rootViewController,
            coordinator: coordinator,
            adFreeStore: adFreeStore
        )
        return mapOutcome(outcome)
    }

    func mapOutcome(_ outcome: RewardedAdManager.RewardOutcome) -> GateResult {
        switch outcome {
            case .granted:
                return .proceed

            case .userClosed:
                lastGateFailureReason = String(localized: "rewarded_gate_failure_not_completed")
                return .userClosed

            case let .failed(reason):
                lastGateFailureReason = String(
                    format: String(localized: "rewarded_gate_failure_show_failed_template"),
                    reason
                )
                return .failed(reason: reason)
        }
    }
}
