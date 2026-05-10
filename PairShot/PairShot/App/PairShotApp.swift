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
    @State private var enteredBackgroundAt: Date?
    @Environment(\.scenePhase) private var scenePhase

    private static let backgroundDwellThreshold: TimeInterval = 30

    init() {
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
                .environment(env.adFreeStore)
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
        await env.consentManager.bootstrap()
        #if canImport(GoogleMobileAds)
            _ = await GADMobileAds.sharedInstance().start()
        #endif
        await env.adFreeStore.refresh()
        env.interstitialAdManager.loadIfNeeded(adFreeStore: env.adFreeStore)
        env.appOpenAdManager.loadIfNeeded(adFreeStore: env.adFreeStore)
        env.rewardedAdManager.loadIfNeeded(adFreeStore: env.adFreeStore)
        env.nativeAdLoader.prefetch(count: 5, adFreeStore: env.adFreeStore)
        hasBootstrappedAds = true
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .background {
            enteredBackgroundAt = Date()
        }

        guard phase == .active else { return }

        Task { @MainActor in
            await env.permissionStatusService.refreshAll()
            await env.adFreeStore.refresh()
            env.interstitialAdManager.loadIfNeeded(adFreeStore: env.adFreeStore)
            env.appOpenAdManager.loadIfNeeded(adFreeStore: env.adFreeStore)
            env.rewardedAdManager.loadIfNeeded(adFreeStore: env.adFreeStore)
            env.nativeAdLoader.prefetch(count: 5, adFreeStore: env.adFreeStore)
            guard let backgroundedAt = enteredBackgroundAt,
                  Date().timeIntervalSince(backgroundedAt) >= Self.backgroundDwellThreshold
            else { return }
            enteredBackgroundAt = nil
            await env.appOpenAdManager.presentIfReady(
                from: BannerAdView.resolveRootViewController(),
                coordinator: env.fullscreenAdCoordinator,
                adFreeStore: env.adFreeStore
            )
        }
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
