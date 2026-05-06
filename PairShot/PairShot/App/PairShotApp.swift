import OSLog
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
                .environment(env.adFreeStore)
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
                    await env.adFreeStore.refreshFromServer(
                        api: env.couponApi,
                        deviceHashProvider: env.deviceHashProvider
                    )
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
        let interstitialManager = env.interstitialAdManager
        let appOpenManager = env.appOpenAdManager
        let rewardedManager = env.rewardedAdManager
        let nativeAdLoader = env.nativeAdLoader
        BootstrapAdsCoordinator.bootstrap(
            adFreeStore: env.adFreeStore,
            ifNotAdFree: { store in
                interstitialManager.loadIfNeeded(adFreeStore: store)
                appOpenManager.loadIfNeeded(adFreeStore: store)
                rewardedManager.loadIfNeeded(adFreeStore: store)
                nativeAdLoader.prefetch(count: 5, adFreeStore: store)
            }
        )
        hasBootstrappedAds = true
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        let previous = lastScenePhase
        defer { lastScenePhase = phase }

        guard phase == .active else { return }

        Task { @MainActor in
            await env.permissionStatusService.refreshAll()
            await env.adFreeStore.refreshFromServer(
                api: env.couponApi,
                deviceHashProvider: env.deviceHashProvider
            )
            env.interstitialAdManager.loadIfNeeded(adFreeStore: env.adFreeStore)
            env.appOpenAdManager.loadIfNeeded(adFreeStore: env.adFreeStore)
            env.rewardedAdManager.loadIfNeeded(adFreeStore: env.adFreeStore)
            env.nativeAdLoader.prefetch(count: 5, adFreeStore: env.adFreeStore)
            guard AppOpenScenePhaseGate.shouldPresent(previous: previous, current: phase) else {
                return
            }
            await env.appOpenAdManager.presentIfReady(
                from: BannerAdView.resolveRootViewController(),
                coordinator: env.fullscreenAdCoordinator,
                adFreeStore: env.adFreeStore
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
        let schema = Schema([AlbumEntity.self, PhotoPairEntity.self, CouponEntity.self, ExportHistoryEntity.self])
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

@MainActor
enum BootstrapAdsCoordinator {
    static func bootstrap(
        adFreeStore: AdFreeStore,
        ifNotAdFree: (AdFreeStore) -> Void
    ) {
        adFreeStore.refresh()
        guard !adFreeStore.isAdFree else { return }
        ifNotAdFree(adFreeStore)
    }
}
