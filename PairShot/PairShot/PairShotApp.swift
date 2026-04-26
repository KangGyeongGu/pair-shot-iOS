import SwiftData
import SwiftUI
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

@main
struct PairShotApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([Project.self, PhotoPair.self, Coupon.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var adFreeStore: AdFreeStore
    @State private var coordinator = FullscreenAdCoordinator()
    @State private var interstitialManager = InterstitialAdManager()
    @State private var appOpenManager = AppOpenAdManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasPresentedColdStartAppOpen = false

    init() {
        // P6.1: bootstrap the Google Mobile Ads SDK as early as possible so
        // ad surfaces (P6.5+) have a warm SDK by the time they appear. The
        // call is idempotent and non-blocking — fine to fire-and-forget
        // from the App initialiser. Wrapped in `canImport` so the project
        // still compiles in environments where the SPM dependency hasn't
        // resolved (CI sandboxes, fresh checkouts before package fetch).
        // v11 SDK exposes `GADMobileAds.sharedInstance().start(...)`; v12+
        // renames to `MobileAds.shared.start(...)`. We use the v11 names
        // since that is the resolved minimum version.
        //
        // P6c advisory: an AdFree-aware `start` skip would save the one
        // network round-trip the SDK does at boot. We don't yet know
        // `isAdFree` here (the AdFreeStore needs the model context, which
        // we initialise on the next line). The boot-time call does not
        // trigger ATT, so deferring this optimisation to P10.5 is fine.
        #if canImport(GoogleMobileAds)
            GADMobileAds.sharedInstance().start(completionHandler: nil)
        #endif

        // Build the AdFreeStore against the same shared container the
        // views see — the underlying `ModelContext` is the main-context
        // of `sharedModelContainer`. Captured as `@State` so SwiftUI
        // observes its `isAdFree` updates.
        let store = AdFreeStore(context: sharedModelContainer.mainContext)
        _adFreeStore = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(adFreeStore)
                .environment(\.fullscreenAdCoordinator, coordinator)
                .environment(interstitialManager)
                .environment(appOpenManager)
                .task {
                    // Cold-start App Open ad surface. Runs once after the
                    // first frame of `ContentView`, when there is a real
                    // active scene and a key window for the SDK to
                    // present from. App.init is too early — no scene yet.
                    await bootstrapAds()
                    if !hasPresentedColdStartAppOpen {
                        hasPresentedColdStartAppOpen = true
                        await appOpenManager.presentIfReady(
                            coldStart: true,
                            from: BannerAdView.resolveRootViewController(),
                            coordinator: coordinator,
                            adFreeStore: adFreeStore
                        )
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    /// Pre-warm interstitial / app-open ads on the first foregrounding.
    /// Skipped when AdFree — `loadIfNeeded` short-circuits internally so
    /// no SDK call is made.
    private func bootstrapAds() async {
        adFreeStore.refresh()
        interstitialManager.loadIfNeeded(adFreeStore: adFreeStore)
        appOpenManager.loadIfNeeded(adFreeStore: adFreeStore)
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
            case .active:
                // Refresh the AdFree status — the user may have redeemed a
                // coupon while we were backgrounded — then attempt the
                // App Open ad. The 4-minute cap inside the manager
                // prevents firing on every brief tap-out.
                Task { @MainActor in
                    adFreeStore.refresh()
                    interstitialManager.loadIfNeeded(adFreeStore: adFreeStore)
                    appOpenManager.loadIfNeeded(adFreeStore: adFreeStore)
                    // Skip the App Open ad on the very first `.active`
                    // event after launch — that's already covered by the
                    // cold-start path in `.task` above.
                    guard hasPresentedColdStartAppOpen else { return }
                    await appOpenManager.presentIfReady(
                        coldStart: false,
                        from: BannerAdView.resolveRootViewController(),
                        coordinator: coordinator,
                        adFreeStore: adFreeStore
                    )
                }
            case .background, .inactive:
                break
            @unknown default:
                break
        }
    }
}
