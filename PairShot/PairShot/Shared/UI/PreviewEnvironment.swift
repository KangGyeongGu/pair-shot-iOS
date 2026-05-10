import SwiftData
import SwiftUI

struct PreviewEnvironment<Content: View>: View {
    let suiteName: String
    @ViewBuilder let content: () -> Content

    private let container = try! ModelContainer(
        for: Schema([AlbumEntity.self, PhotoPairEntity.self, ExportHistoryEntity.self]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        let appSettings = AppSettings(defaults: UserDefaults(suiteName: suiteName) ?? .standard)
        let env = AppEnvironment(modelContainer: container, appSettings: appSettings)
        return content()
            .modelContainer(container)
            .environment(env)
            .environment(\.fullscreenAdCoordinator, env.fullscreenAdCoordinator)
            .environment(env.interstitialAdManager)
            .environment(env.appOpenAdManager)
            .environment(env.rewardedAdManager)
            .environment(env.nativeAdLoader)
            .environment(env.adFreeStore)
            .environment(env.trackingService)
            .environment(env.appSettings)
    }
}
