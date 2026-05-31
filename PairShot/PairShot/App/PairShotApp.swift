import SwiftData
import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

@main
struct PairShotApp: App {
    private static let backgroundDwellThreshold: TimeInterval = 30

    let containerBootstrap: ModelContainerBootstrap = .bootstrap()

    var sharedModelContainer: ModelContainer {
        containerBootstrap.container
    }

    @State private var env: AppEnvironment
    @State private var hasBootstrappedAds = false
    @State private var hasInitializedBootstrap = false
    @State private var showFallbackAlert: Bool
    @State private var enteredBackgroundAt: Date?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(showFallbackAlert: $showFallbackAlert)
                .environment(env)
                .environment(\.fullscreenAdCoordinator, env.fullscreenAdCoordinator)
                .environment(env.interstitialAdManager)
                .environment(env.appOpenAdManager)
                .environment(env.rewardedAdManager)
                .environment(env.nativeAdLoader)
                .environment(env.promotionStore)
                .environment(env.trackingService)
                .environment(env.appSettings)
                .environment(env.productsService)
                .environment(env.subscriptionStore)
                .environment(env.transactionListener)
                .environment(env.membership)
                .environment(env.exportCompletionCoordinator)
                .environment(env.tutorialCoordinator)
                .environment(env.exportTutorialCoordinator)
                .tutorialModeBinding(env.tutorialCoordinator)
                .environment(\.locale, env.appSettings.resolvedLocale)
                .preferredColorScheme(env.appSettings.resolvedColorScheme)
                .dynamicTypeSize(env.appSettings.appTextSize.dynamicTypeSize)
                .task {
                    applyContentSizeCategoryToConnectedScenes()
                    await tryInitializeBootstrap()
                }
                .onChange(of: env.appSettings.appTextSize) { _, _ in
                    applyContentSizeCategoryToConnectedScenes()
                }
                .onChange(of: env.consentManager.canRequestAds) { _, canRequest in
                    guard canRequest, !hasBootstrappedAds else { return }
                    Task { @MainActor in await startAdsAfterConsent() }
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
            if newPhase == .active {
                Task { @MainActor in await tryInitializeBootstrap() }
            }
        }
    }

    init() {
        _showFallbackAlert = State(initialValue: containerBootstrap.fallbackActive)
        let environment = AppEnvironment(modelContainer: containerBootstrap.container)
        AppLanguageBundleSync.apply(environment.appSettings.language)
        environment.appSettings.launchCount += 1
        environment.exportPresetStore.seedDefaultIfNeeded(
            name: String(localized: "export_preset_default_name"),
        )
        _env = State(initialValue: environment)
    }

    private func applyContentSizeCategoryToConnectedScenes() {
        let category = env.appSettings.appTextSize.preferredContentSizeCategory
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.traitOverrides.preferredContentSizeCategory = category
        }
    }

    private func tryInitializeBootstrap() async {
        guard !hasInitializedBootstrap else { return }
        guard scenePhase == .active else { return }
        hasInitializedBootstrap = true
        await env.permissionStatusService.refreshAll()
        if !env.permissionStatusService.hasRequestedInitialPermissions {
            await env.permissionStatusService.requestAllInOrder()
        }
        await bootstrapSubscription()
        await bootstrapConsent()
        _ = await env.trackingService.requestIfUndetermined()
        await bootstrapAds()
    }

    func bootstrapSubscription() async {
        let env = env
        env.transactionListener.start { _ in
            await env.subscriptionStore.refresh()
            await MainActor.run { env.reconcileMembershipDowngrade() }
        }
        await env.subscriptionStore.refresh()
        env.reconcileMembershipDowngrade()
        try? await env.productsService.loadProducts()
    }

    func bootstrapConsent() async {
        await env.consentManager.bootstrap()
    }

    func bootstrapAds() async {
        guard !env.membership.proIsActive else { return }
        guard env.consentManager.canRequestAds else { return }
        await startAdsAfterConsent()
    }

    private func startAdsAfterConsent() async {
        guard !hasBootstrappedAds else { return }
        hasBootstrappedAds = true
        #if canImport(GoogleMobileAds)
            _ = await MobileAds.shared.start()
        #endif
        await env.promotionStore.refresh()
        env.interstitialAdManager.loadIfNeeded(
            promotionStore: env.promotionStore,
            subscriptionStore: env.subscriptionStore,
        )
        env.appOpenAdManager.loadIfNeeded(
            promotionStore: env.promotionStore,
            subscriptionStore: env.subscriptionStore,
        )
        env.rewardedAdManager.loadIfNeeded(
            promotionStore: env.promotionStore,
            subscriptionStore: env.subscriptionStore,
        )
        env.nativeAdLoader.prefetch(
            count: 5,
            promotionStore: env.promotionStore,
            subscriptionStore: env.subscriptionStore,
        )
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .background {
            enteredBackgroundAt = Date()
        }

        guard phase == .active else { return }

        Task { @MainActor in
            await env.permissionStatusService.refreshAll()
            env.photoLibrarySync.reconcile()
            await env.promotionStore.refresh()
            guard hasBootstrappedAds else { return }
            env.interstitialAdManager.loadIfNeeded(
                promotionStore: env.promotionStore,
                subscriptionStore: env.subscriptionStore,
            )
            env.appOpenAdManager.loadIfNeeded(
                promotionStore: env.promotionStore,
                subscriptionStore: env.subscriptionStore,
            )
            env.rewardedAdManager.loadIfNeeded(
                promotionStore: env.promotionStore,
                subscriptionStore: env.subscriptionStore,
            )
            env.nativeAdLoader.prefetch(
                count: 5,
                promotionStore: env.promotionStore,
                subscriptionStore: env.subscriptionStore,
            )
            guard let backgroundedAt = enteredBackgroundAt,
                  Date().timeIntervalSince(backgroundedAt) >= Self.backgroundDwellThreshold
            else { return }
            enteredBackgroundAt = nil
            await env.appOpenAdManager.presentIfReady(
                from: BannerAdView.resolveRootViewController(),
                coordinator: env.fullscreenAdCoordinator,
                promotionStore: env.promotionStore,
                subscriptionStore: env.subscriptionStore,
            )
        }
    }
}

struct ModelContainerBootstrap {
    let container: ModelContainer
    let fallbackActive: Bool

    static func bootstrap() -> Self {
        let schema = Schema(versionedSchema: SchemaV1.self)
        do {
            _ = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true,
            )
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: PairShotMigrationPlan.self,
                configurations: [configuration],
            )
            return Self(container: container, fallbackActive: false)
        } catch {
            do {
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try ModelContainer(
                    for: schema,
                    migrationPlan: PairShotMigrationPlan.self,
                    configurations: [configuration],
                )
                return Self(container: container, fallbackActive: true)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
}
