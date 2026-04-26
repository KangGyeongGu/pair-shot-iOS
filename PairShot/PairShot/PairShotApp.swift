import SwiftData
import SwiftUI
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

@main
struct PairShotApp: App {
    /// Bootstrapped `ModelContainer` plus a flag indicating whether the
    /// disk-backed store opened cleanly. Audit-A — `fatalError` on first
    /// failure is replaced with an in-memory fallback so the app keeps
    /// launching when the on-disk store is corrupt / migration-incompatible.
    /// The user is alerted via ``ContentView`` so they understand data
    /// won't persist across launches.
    let containerBootstrap: ModelContainerBootstrap = .bootstrap()

    var sharedModelContainer: ModelContainer {
        containerBootstrap.container
    }

    @State private var adFreeStore: AdFreeStore
    @State private var coordinator = FullscreenAdCoordinator()
    @State private var interstitialManager = InterstitialAdManager()
    @State private var appOpenManager = AppOpenAdManager()
    @State private var rewardedManager = RewardedAdManager()
    @State private var nativeAdLoader = NativeAdLoader()
    @State private var trackingService = TrackingAuthorizationService()
    @State private var appSettings = AppSettings()
    @State private var hasBootstrappedAds = false
    @State private var hasPresentedColdStartAppOpen = false
    /// Audit-A — surfaces the in-memory fallback alert via `ContentView`.
    @State private var showFallbackAlert: Bool
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // P6.1: bootstrap the Google Mobile Ads SDK as early as possible
        // so ad surfaces have a warm SDK by the time they appear. The
        // call is idempotent and non-blocking. Wrapped in `canImport` so
        // the project still compiles in environments where the SPM
        // dependency hasn't resolved (CI sandboxes).
        //
        // P6c advisory: SDK boot doesn't trigger ATT, so the boot call
        // can run before the prompt. ATT is requested explicitly inside
        // `bootstrapAds()` below — *before* the first ad load — so the
        // SDK has a chance to honour the user's choice on its first
        // request.
        #if canImport(GoogleMobileAds)
            GADMobileAds.sharedInstance().start(completionHandler: nil)
        #endif

        let store = AdFreeStore(context: containerBootstrap.container.mainContext)
        _adFreeStore = State(initialValue: store)
        _showFallbackAlert = State(initialValue: containerBootstrap.fallbackActive)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(showFallbackAlert: $showFallbackAlert)
                .environment(adFreeStore)
                .environment(\.fullscreenAdCoordinator, coordinator)
                .environment(interstitialManager)
                .environment(appOpenManager)
                .environment(rewardedManager)
                .environment(nativeAdLoader)
                .environment(trackingService)
                .environment(appSettings)
                .task {
                    // First-frame bootstrap: ATT prompt → ad loads in
                    // strict order so the SDK never fires its initial
                    // request before the user has responded to the
                    // tracking prompt. Cold-start App Open ad is
                    // attempted after the bootstrap completes.
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

    /// P6d — single bootstrap entry point shared by cold-start and
    /// (idempotently) every foreground re-activation.
    ///
    /// Order is load-bearing:
    /// 1. Refresh `AdFreeStore` so a coupon redeemed while backgrounded
    ///    is honoured before any ad call.
    /// 2. Skip the rest entirely if AdFree is active (CLAUDE.md core
    ///    principle 7 — no unnecessary network or ATT prompt).
    /// 3. Request ATT permission *if* still `.notDetermined`. The SDK
    ///    must see the user's decision before its first ad request to
    ///    honour the IDFA / non-IDFA toggle.
    /// 4. Pre-load every surface (interstitial / app-open / rewarded)
    ///    plus the native-ad pool. Each `loadIfNeeded` is internally
    ///    AdFree-aware too, but the outer guard above means we never
    ///    even reach this branch when entitled.
    func bootstrapAds() async {
        await BootstrapAdsCoordinator.bootstrap(
            adFreeStore: adFreeStore,
            tracking: trackingService,
            ifNotAdFree: { [interstitialManager, appOpenManager, rewardedManager, nativeAdLoader] in
                interstitialManager.loadIfNeeded(adFreeStore: $0)
                appOpenManager.loadIfNeeded(adFreeStore: $0)
                rewardedManager.loadIfNeeded(adFreeStore: $0)
                nativeAdLoader.prefetch(count: 5, adFreeStore: $0)
            }
        )
        hasBootstrappedAds = true
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
            case .active:
                Task { @MainActor in
                    adFreeStore.refresh()
                    interstitialManager.loadIfNeeded(adFreeStore: adFreeStore)
                    appOpenManager.loadIfNeeded(adFreeStore: adFreeStore)
                    rewardedManager.loadIfNeeded(adFreeStore: adFreeStore)
                    nativeAdLoader.prefetch(count: 5, adFreeStore: adFreeStore)
                    // Skip the App Open ad on the very first `.active`
                    // event after launch — that's covered by the
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

/// Audit-A — replaces the original `fatalError(...)` in
/// `PairShotApp.sharedModelContainer` with a graceful in-memory fallback.
///
/// SwiftData failures fall into three buckets:
///
/// 1. Disk-backed open succeeds → ship the user their persistent store.
/// 2. Disk-backed open fails (corrupt store / migration mismatch / disk
///    full) → open an isolated in-memory store so the app launches and
///    the user can at least see/dismiss an alert. **Data does not persist
///    across launches in this mode.**
/// 3. In-memory open also fails → unrecoverable system condition; trap
///    so the crash log surfaces a real underlying defect rather than
///    masking it.
///
/// The result type carries a `fallbackActive` flag the App scene reads
/// to surface a one-shot user-visible alert via `ContentView`.
struct ModelContainerBootstrap {
    let container: ModelContainer
    let fallbackActive: Bool

    static func bootstrap() -> ModelContainerBootstrap {
        let schema = Schema([Project.self, PhotoPair.self, Coupon.self])
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return ModelContainerBootstrap(container: container, fallbackActive: false)
        } catch {
            // Disk-backed open failed — likely corrupt store or
            // incompatible migration. Try an in-memory fallback so we
            // can at least present an alert to the user.
            do {
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                return ModelContainerBootstrap(container: container, fallbackActive: true)
            } catch {
                // Both stores failed — system is in a state we cannot
                // recover from in-process. Re-emit the original error
                // signature so debug logs match the legacy behaviour.
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
}

/// Pure-ish coordinator extracted from `PairShotApp.bootstrapAds()` so
/// the ATT-then-load sequencing is unit-testable without spinning up a
/// SwiftUI scene.
///
/// The coordinator does **not** know about Google Mobile Ads — it only
/// orchestrates the order of `AdFreeStore` refresh → ATT request → load
/// callback. Callers wire concrete `loadIfNeeded`/`prefetch` calls via
/// the `ifNotAdFree` closure.
@MainActor
enum BootstrapAdsCoordinator {
    /// Runs the bootstrap sequence.
    /// - Parameters:
    ///   - adFreeStore: Refreshed at step 1 so a redeemed coupon short
    ///     -circuits subsequent steps.
    ///   - tracking: `TrackingAuthorizationService` — `requestIfUndetermined()`
    ///     is called only when the user is *not* AdFree.
    ///   - ifNotAdFree: Closure invoked **after** ATT has returned (or
    ///     was skipped because already decided). Receives the same
    ///     `AdFreeStore` instance so individual managers can re-check.
    static func bootstrap(
        adFreeStore: AdFreeStore,
        tracking: TrackingAuthorizationService,
        ifNotAdFree: (AdFreeStore) -> Void
    ) async {
        adFreeStore.refresh()
        guard !adFreeStore.isAdFree else { return }
        _ = await tracking.requestIfUndetermined()
        ifNotAdFree(adFreeStore)
    }
}
