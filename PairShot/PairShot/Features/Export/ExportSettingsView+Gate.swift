import SwiftUI
import UIKit

extension ExportSettingsView {
    @MainActor
    func confirmWatermarkGate() async {
        let result = await viewModel.confirmWatermarkGateAd(
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: BannerAdView.resolveTopPresentedViewController(),
        )
        if case .proceed = result {
            onPushWatermarkSettings?()
        }
    }

    @MainActor
    func confirmCombineGate() async {
        let result = await viewModel.confirmCombineGateAd(
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: BannerAdView.resolveTopPresentedViewController(),
        )
        if case .proceed = result {
            onPushCombineSettings?()
        }
    }

    func observeEvents() async {
        for await event in viewModel.events {
            switch event {
                case .completed:
                    exportCompletionCoordinator.notifyCompleted()

                case .dismiss:
                    dismiss()
            }
        }
    }
}
