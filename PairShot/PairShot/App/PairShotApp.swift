import SwiftData
import SwiftUI
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

@main
struct PairShotApp: App {
    let containerBootstrap: ModelContainerBootstrap = .bootstrap()

    var sharedModelContainer: ModelContainer {
        containerBootstrap.container
    }

    @State private var env: AppEnvironment
    @State private var hasBootstrappedAds = false
    @State private var showFallbackAlert: Bool
    @State private var lastScenePhase: ScenePhase = .background
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if canImport(GoogleMobileAds)
            GADMobileAds.sharedInstance().start(completionHandler: nil)
        #endif

        _showFallbackAlert = State(initialValue: containerBootstrap.fallbackActive)
        let environment = AppEnvironment(modelContainer: containerBootstrap.container)
        AppLanguageBundleSync.apply(environment.appSettings.language)
        _env = State(initialValue: environment)
    }

    var body: some Scene {
        WindowGroup {
            RootView(showFallbackAlert: $showFallbackAlert)
                .environment(env)
                .environment(\.fullscreenAdCoordinator, env.fullscreenAdCoordinator)
                .environment(env.interstitialAdManager)
                .environment(env.appOpenAdManager)
                .environment(env.rewardedAdManager)
                .environment(env.nativeAdLoader)
                .environment(env.trackingService)
                .environment(env.appSettings)
                .environment(\.locale, env.appSettings.resolvedLocale)
                .preferredColorScheme(env.appSettings.resolvedColorScheme)
                .task {
                    await env.permissionStatusService.refreshAll()
                    if !env.permissionStatusService.hasRequestedInitialPermissions {
                        await env.permissionStatusService.requestAllInOrder()
                    }
                    _ = await env.trackingService.requestIfUndetermined()
                    await bootstrapAds()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    func bootstrapAds() async {
        env.interstitialAdManager.loadIfNeeded()
        env.appOpenAdManager.loadIfNeeded()
        env.rewardedAdManager.loadIfNeeded()
        env.nativeAdLoader.prefetch(count: 5)
        hasBootstrappedAds = true
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        let previous = lastScenePhase
        defer { lastScenePhase = phase }

        guard phase == .active else { return }

        Task { @MainActor in
            await env.permissionStatusService.refreshAll()
            env.interstitialAdManager.loadIfNeeded()
            env.appOpenAdManager.loadIfNeeded()
            env.rewardedAdManager.loadIfNeeded()
            env.nativeAdLoader.prefetch(count: 5)
            guard AppOpenScenePhaseGate.shouldPresent(previous: previous, current: phase) else {
                return
            }
            await env.appOpenAdManager.presentIfReady(
                from: BannerAdView.resolveRootViewController(),
                coordinator: env.fullscreenAdCoordinator
            )
        }
    }
}

enum AppOpenScenePhaseGate {
    static func shouldPresent(previous: ScenePhase, current: ScenePhase) -> Bool {
        guard current == .active else { return false }
        return previous == .background
    }
}

struct ModelContainerBootstrap {
    let container: ModelContainer
    let fallbackActive: Bool

    static func bootstrap() -> Self {
        let schema = Schema([AlbumEntity.self, PhotoPairEntity.self, ExportHistoryEntity.self])
        do {
            _ = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            return Self(container: container, fallbackActive: false)
        } catch {
            do {
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                return Self(container: container, fallbackActive: true)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
}
