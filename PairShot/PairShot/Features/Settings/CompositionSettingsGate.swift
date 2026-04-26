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
            Text(String(localized: "프리미엄 설정"))
                .font(.title3.bold())
            Text(String(localized: "광고를 시청하면 이 세션 동안 잠금이 해제됩니다"))
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
                        String(localized: "광고 보고 잠금 해제"),
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
                Button(String(localized: "광고 다시 불러오기")) {
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
                lastFailureReason = String(localized: "보상을 받으려면 광고를 끝까지 시청하세요")

            case let .failed(reason):
                lastFailureReason = String(
                    format: String(localized: "광고를 표시할 수 없습니다 (%@)"),
                    reason
                )
        }
    }

    @MainActor
    private func rewardedRootViewController() -> UIViewController? {
        BannerAdView.resolveRootViewController()
    }
}
