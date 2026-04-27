import SwiftUI

struct CompositionSettingsGate<Content: View>: View {
    @Environment(AdFreeStore.self) private var adFreeStore
    @Environment(RewardedAdManager.self) private var rewardedManager
    @Environment(\.fullscreenAdCoordinator) private var coordinator

    let unlockID: RewardedAdManager.UnlockID
    @ViewBuilder let content: () -> Content

    @State private var isPresenting = false
    @State private var lastFailureReason: String?

    init(
        unlockID: RewardedAdManager.UnlockID = .compositionSettings,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.unlockID = unlockID
        self.content = content
    }

    var body: some View {
        if RewardedSessionGate.shouldShowGate(
            unlockID: unlockID,
            sessionUnlocks: rewardedManager.sessionUnlocks,
            isAdFree: adFreeStore.isAdFree
        ) {
            lockScreen
        } else {
            content()
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(String(localized: "rewarded_gate_premium_title"))
                .font(.title3.bold())
            Text(String(localized: "rewarded_gate_session_unlock_hint"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task { await presentReward() }
            } label: {
                if isPresenting {
                    ProgressView()
                } else {
                    Label(
                        String(localized: "rewarded_gate_button_watch"),
                        systemImage: "play.rectangle.fill"
                    )
                    .font(.headline)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPresenting || !rewardedManager.isLoaded)

            if let reason = lastFailureReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !rewardedManager.isLoaded, !rewardedManager.isLoading {
                Button(String(localized: "rewarded_gate_button_reload")) {
                    rewardedManager.loadIfNeeded(adFreeStore: adFreeStore)
                }
                .font(.caption)
            }
        }
        .padding()
        .task {
            rewardedManager.loadIfNeeded(adFreeStore: adFreeStore)
        }
    }

    @MainActor
    private func presentReward() async {
        isPresenting = true
        defer { isPresenting = false }
        lastFailureReason = nil

        let outcome = await rewardedManager.presentForReward(
            unlockID,
            from: rewardedRootViewController(),
            coordinator: coordinator,
            adFreeStore: adFreeStore
        )
        switch outcome {
            case .granted, .skipped:
                lastFailureReason = nil

            case .userClosed:
                lastFailureReason = String(localized: "rewarded_gate_failure_not_completed")

            case let .failed(reason):
                lastFailureReason = String(
                    format: String(localized: "rewarded_gate_failure_show_failed_template"),
                    reason
                )
        }
    }

    @MainActor
    private func rewardedRootViewController() -> UIViewController? {
        BannerAdView.resolveRootViewController()
    }
}
