import SwiftData
import SwiftUI

@MainActor
struct PreviewEnvironment<Content: View>: View {
    let suiteName: String
    @ViewBuilder let content: () -> Content

    // swiftlint:disable:next force_try
    private let container = try! ModelContainer(
        for: Schema([Album.self, PhotoPair.self, CouponEntity.self]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        let appSettings = AppSettings(defaults: UserDefaults(suiteName: suiteName) ?? .standard)
        let env = AppEnvironment(modelContainer: container, appSettings: appSettings)
        return content()
            .modelContainer(container)
            .environment(env)
            .environment(env.adFreeStore)
            .environment(\.fullscreenAdCoordinator, env.fullscreenAdCoordinator)
            .environment(env.interstitialAdManager)
            .environment(env.appOpenAdManager)
            .environment(env.rewardedAdManager)
            .environment(env.nativeAdLoader)
            .environment(env.trackingService)
            .environment(env.appSettings)
    }
}
