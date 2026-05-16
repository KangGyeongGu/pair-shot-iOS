import Foundation
import UIKit

extension ExportSettingsViewModel {
    var gateCoordinator: RewardedGateCoordinator {
        RewardedGateCoordinator(membership: membership)
    }

    func requestWatermarkGate(rewardedManager: RewardedAdManager) -> Bool {
        requestGate(
            unlockID: .watermarkSettings,
            rewardedManager: rewardedManager,
            dialogFlag: \.showWatermarkGateDialog,
        )
    }

    func requestCombineGate(rewardedManager: RewardedAdManager) -> Bool {
        requestGate(
            unlockID: .compositionSettings,
            rewardedManager: rewardedManager,
            dialogFlag: \.showCombineGateDialog,
        )
    }

    func confirmWatermarkGateAd(
        rewardedManager: RewardedAdManager,
        coordinator: FullscreenAdCoordinator,
        rootViewController: UIViewController?,
    ) async -> GateResult {
        await presentGateAd(
            unlockID: .watermarkSettings,
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: rootViewController,
        )
    }

    func confirmCombineGateAd(
        rewardedManager: RewardedAdManager,
        coordinator: FullscreenAdCoordinator,
        rootViewController: UIViewController?,
    ) async -> GateResult {
        await presentGateAd(
            unlockID: .compositionSettings,
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: rootViewController,
        )
    }

    private func requestGate(
        unlockID: RewardedAdManager.UnlockID,
        rewardedManager: RewardedAdManager,
        dialogFlag: ReferenceWritableKeyPath<ExportSettingsViewModel, Bool>,
    ) -> Bool {
        lastGateFailureReason = nil
        let coordinator = gateCoordinator
        if coordinator.shouldProceedWithoutGate(unlockID: unlockID, rewardedManager: rewardedManager) {
            return true
        }
        coordinator.loadAd(rewardedManager: rewardedManager)
        self[keyPath: dialogFlag] = true
        return false
    }

    private func presentGateAd(
        unlockID: RewardedAdManager.UnlockID,
        rewardedManager: RewardedAdManager,
        coordinator: FullscreenAdCoordinator,
        rootViewController: UIViewController?,
    ) async -> GateResult {
        lastGateFailureReason = nil
        let outcome = await gateCoordinator.presentGateAd(
            unlockID: unlockID,
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: rootViewController,
        )
        lastGateFailureReason = outcome.failureReason
        return outcome.result
    }
}
