import AppTrackingTransparency
import Foundation
import Observation
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

// MARK: - Pure gate

/// Pure decision: should we attempt to present an App Open ad on the
/// given lifecycle event?
///
/// Cold-start vs background-foreground are treated symmetrically: both
/// must respect the same minimum gap (default 4 minutes) between
/// presentations so the user never sees an App Open ad twice in quick
/// succession.
enum AppOpenAdGate {
    /// Default minimum elapsed seconds between App Open presentations.
    /// 240 s (4 min) matches the Google guidance for App Open.
    nonisolated static let defaultMinimumInterval: TimeInterval = 240

    /// - Parameters:
    ///   - coldStart: `true` when the app just launched, `false` when
    ///     transitioning back from background to foreground.
    ///   - lastShownAt: Last successful App Open presentation, or `nil`.
    ///   - now: Current wall-clock time.
    ///   - minimumInterval: Minimum elapsed seconds between presentations.
    /// - Returns: `true` when an App Open ad attempt is allowed.
    static func shouldPresent(
        coldStart _: Bool,
        lastShownAt: Date?,
        now: Date,
        minimumInterval: TimeInterval = defaultMinimumInterval
    ) -> Bool {
        // Audit-B — `coldStart` is intentionally ignored. Both
        // lifecycle paths share the same elapsed-since-last cap so a
        // fast app-quit-and-relaunch can't bypass the gate. The
        // parameter is kept so callers can still document intent at
        // the call site, but the policy is symmetric.
        guard let lastShownAt else { return true }
        return now.timeIntervalSince(lastShownAt) >= minimumInterval
    }
}

// MARK: - Manager

/// P6.9 — `GADAppOpenAd` manager.
///
/// Two presentation triggers:
/// 1. **Cold start** — fired from `ContentView.task` (or equivalent first
///    visible view) so the SDK has a foreground scene to present from.
///    Calling from `App.init` doesn't work — there's no active scene yet.
/// 2. **Background → foreground** — fired from
///    `@Environment(\.scenePhase).onChange` in `PairShotApp` when the
///    phase transitions to `.active` and we previously saw `.background`.
///
/// Both paths funnel through `presentIfReady(coldStart:)` which:
/// - Skips when AdFree is active.
/// - Skips when the 4-minute cap hasn't elapsed.
/// - Acquires the `FullscreenAdCoordinator` slot to prevent collisions
///   with an Interstitial that fired off a sheet dismissal at the same
///   time.
@MainActor
@Observable
final class AppOpenAdManager {
    /// `true` once an ad object is loaded and ready to present.
    private(set) var isLoaded: Bool = false

    /// `true` while a load request is in flight.
    private(set) var isLoading: Bool = false

    /// Timestamp of the last successful presentation.
    private(set) var lastShownAt: Date?

    private let minimumInterval: TimeInterval

    #if canImport(GoogleMobileAds)
        private var ad: GADAppOpenAd?
        private let presentationDelegate: AppOpenPresentationDelegate
    #endif

    init(minimumInterval: TimeInterval = AppOpenAdGate.defaultMinimumInterval) {
        self.minimumInterval = minimumInterval
        #if canImport(GoogleMobileAds)
            presentationDelegate = AppOpenPresentationDelegate()
        #endif
    }

    /// Pre-loads an App Open ad if not already loaded / loading and the
    /// user is not ad-free.
    func loadIfNeeded(
        adUnitID: String? = nil,
        adFreeStore: AdFreeStore? = nil
    ) {
        if let adFreeStore, adFreeStore.isAdFree { return }
        guard !isLoaded, !isLoading else { return }
        let resolvedUnitID = adUnitID ?? AdsConfig.appOpen
        #if canImport(GoogleMobileAds)
            // Audit-B — funnel through `AdRequestBuilder` so the npa
            // signal is attached when ATT is denied / restricted.
            guard let request = AdRequestBuilder.build(
                isAdFree: adFreeStore?.isAdFree ?? false,
                attStatus: ATTrackingManager.trackingAuthorizationStatus
            ) else { return }
            isLoading = true
            GADAppOpenAd.load(
                withAdUnitID: resolvedUnitID,
                request: request
            ) { [weak self] ad, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    isLoading = false
                    if let ad {
                        self.ad = ad
                        isLoaded = true
                        ad.fullScreenContentDelegate = presentationDelegate
                    } else {
                        self.ad = nil
                        isLoaded = false
                    }
                }
            }
        #endif
    }

    /// Attempts to present the App Open ad.
    ///
    /// - Parameters:
    ///   - coldStart: Lifecycle source — true on first-visible-view, false
    ///     on `scenePhase` transition `.background → .active`.
    ///   - rootViewController: Resolved via `UIApplication.firstKeyWindow?.rootViewController`
    ///     by the call site; passed in so the manager stays UIKit-bridge-free.
    ///   - coordinator: Fullscreen serialisation lock.
    ///   - adFreeStore: Current entitlement.
    ///   - now: Pinnable for tests.
    /// - Returns: `true` if the SDK was asked to present.
    @discardableResult
    func presentIfReady(
        coldStart: Bool,
        from rootViewController: UIViewController?,
        coordinator: FullscreenAdCoordinator,
        adFreeStore: AdFreeStore? = nil,
        adUnitID: String? = nil,
        now: Date = .now
    ) async -> Bool {
        if let adFreeStore, adFreeStore.isAdFree { return false }
        guard isLoaded else { return false }
        guard AppOpenAdGate.shouldPresent(
            coldStart: coldStart,
            lastShownAt: lastShownAt,
            now: now,
            minimumInterval: minimumInterval
        ) else { return false }
        guard await coordinator.tryAcquire() else { return false }

        #if canImport(GoogleMobileAds)
            guard let ad else {
                await coordinator.release()
                return false
            }
            presentationDelegate.onDismiss = { [weak coordinator] in
                Task { await coordinator?.release() }
            }
            presentationDelegate.onFailToPresent = { [weak coordinator] in
                Task { await coordinator?.release() }
            }
            ad.present(fromRootViewController: rootViewController)
            lastShownAt = now
            self.ad = nil
            isLoaded = false
            loadIfNeeded(adUnitID: adUnitID ?? AdsConfig.appOpen, adFreeStore: adFreeStore)
            return true
        #else
            lastShownAt = now
            await coordinator.release()
            return true
        #endif
    }
}

#if canImport(GoogleMobileAds)
    @MainActor
    private final class AppOpenPresentationDelegate: NSObject, GADFullScreenContentDelegate {
        var onDismiss: (() -> Void)?
        var onFailToPresent: (() -> Void)?

        nonisolated func adDidDismissFullScreenContent(_: any GADFullScreenPresentingAd) {
            Task { @MainActor [weak self] in
                self?.onDismiss?()
            }
        }

        nonisolated func ad(
            _: any GADFullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError _: Error
        ) {
            Task { @MainActor [weak self] in
                self?.onFailToPresent?()
            }
        }
    }
#endif
