import AppTrackingTransparency
import Foundation
import Observation
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

// MARK: - Pure frequency-cap helper

/// Pure decision: is enough time elapsed since the last interstitial
/// presentation to allow another one?
///
/// Pulled out of `InterstitialAdManager` so the policy is unit-testable
/// without spinning up the SDK. Mirrors the Android implementation's
/// "minimum 5 minutes between interstitials" cap.
enum InterstitialFrequencyGate {
    /// - Parameters:
    ///   - now: Current wall-clock time (`Date.now` in production; tests
    ///     can pin a fixed value).
    ///   - lastShownAt: Timestamp of the last successful presentation,
    ///     or `nil` if no interstitial has been shown this session.
    ///   - minimumInterval: Minimum elapsed seconds between presentations.
    /// - Returns: `true` when the SDK should be asked to present the ad.
    static func shouldPresent(
        now: Date,
        lastShownAt: Date?,
        minimumInterval: TimeInterval
    ) -> Bool {
        guard let lastShownAt else { return true }
        return now.timeIntervalSince(lastShownAt) >= minimumInterval
    }
}

// MARK: - Manager

/// P6.6 — `GADInterstitialAd` lifecycle manager.
///
/// Responsibilities:
/// - Pre-load an interstitial in the background so the next "natural
///   transition" (e.g. composite-result sheet dismissal in
///   `ComparisonView`) can show it immediately.
/// - Honour AdFree: if the user has redeemed a coupon, no SDK call is
///   made.
/// - Honour the 5-minute frequency cap so back-to-back composites don't
///   spam ads at the user.
/// - Coordinate with `FullscreenAdCoordinator` so an interstitial doesn't
///   collide with an App Open / Rewarded ad.
///
/// Per CLAUDE.md core principle 7, every ad surface in the app must be
/// AdFree-aware; the gate lives **inside** the manager so callers don't
/// need to remember to guard.
@MainActor
@Observable
final class InterstitialAdManager {
    /// Default minimum gap between interstitial presentations.
    /// Five minutes matches the Android v1.1.3 reference.
    nonisolated static let defaultMinimumInterval: TimeInterval = 300

    /// `true` once an ad object is loaded and ready to present.
    private(set) var isLoaded: Bool = false

    /// `true` while a load request is in-flight. The view should not
    /// kick off a second load while one is pending.
    private(set) var isLoading: Bool = false

    /// Last successful presentation timestamp, used by the frequency
    /// gate. Reset to `nil` on first launch.
    private(set) var lastShownAt: Date?

    private let minimumInterval: TimeInterval

    #if canImport(GoogleMobileAds)
        private var ad: GADInterstitialAd?
        private let presentationDelegate: InterstitialPresentationDelegate
    #endif

    init(minimumInterval: TimeInterval = InterstitialAdManager.defaultMinimumInterval) {
        self.minimumInterval = minimumInterval
        #if canImport(GoogleMobileAds)
            presentationDelegate = InterstitialPresentationDelegate()
        #endif
    }

    /// Pre-loads an interstitial if one is not already loaded or
    /// in-flight, and the user is not ad-free.
    ///
    /// - Parameters:
    ///   - adUnitID: AdMob unit id (test in DEBUG, prod in RELEASE — see
    ///     `AdsConfig.interstitial`).
    ///   - adFreeStore: Current ad-free entitlement; `nil` is treated as
    ///     "not ad-free" so callers don't have to inject a placeholder.
    func loadIfNeeded(
        adUnitID: String? = nil,
        adFreeStore: AdFreeStore? = nil
    ) {
        if let adFreeStore, adFreeStore.isAdFree { return }
        guard !isLoaded, !isLoading else { return }
        let resolvedUnitID = adUnitID ?? AdsConfig.interstitial
        #if canImport(GoogleMobileAds)
            // Audit-B — funnel through `AdRequestBuilder` so the npa
            // signal is attached when the user has denied / restricted
            // ATT. The helper also re-asserts the AdFree guard so a
            // future caller wiring won't accidentally bypass it.
            guard let request = AdRequestBuilder.build(
                isAdFree: adFreeStore?.isAdFree ?? false,
                attStatus: ATTrackingManager.trackingAuthorizationStatus
            ) else { return }
            isLoading = true
            GADInterstitialAd.load(
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

    /// Attempts to present an interstitial.
    ///
    /// Short-circuits on:
    /// - AdFree active.
    /// - No ad loaded yet.
    /// - Frequency cap not yet elapsed.
    /// - Coordinator slot busy.
    ///
    /// On success the slot is released after the ad is dismissed (via
    /// the delegate callback) and a fresh prefetch is kicked off so the
    /// next caller has a warm ad.
    /// - Returns: `true` if the SDK was asked to present.
    @discardableResult
    func presentIfReady(
        from rootViewController: UIViewController?,
        coordinator: FullscreenAdCoordinator,
        adFreeStore: AdFreeStore? = nil,
        adUnitID: String? = nil,
        now: Date = .now
    ) async -> Bool {
        if let adFreeStore, adFreeStore.isAdFree { return false }
        guard isLoaded else { return false }
        guard InterstitialFrequencyGate.shouldPresent(
            now: now,
            lastShownAt: lastShownAt,
            minimumInterval: minimumInterval
        ) else { return false }
        guard await coordinator.tryAcquire() else { return false }

        #if canImport(GoogleMobileAds)
            guard let ad else {
                await coordinator.release()
                return false
            }
            // Wire the delegate to release the coordinator after the ad is
            // dismissed. Capturing `coordinator` strongly here is fine — the
            // delegate is owned by `self` and lives as long as the manager.
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
            // Prefetch the next interstitial so subsequent transitions have
            // a ready ad without an additional network round-trip.
            loadIfNeeded(adUnitID: adUnitID ?? AdsConfig.interstitial, adFreeStore: adFreeStore)
            return true
        #else
            // Without the SDK linked we still record the "presentation" so
            // tests can validate frequency-cap state transitions.
            lastShownAt = now
            await coordinator.release()
            return true
        #endif
    }
}

#if canImport(GoogleMobileAds)
    /// Tiny `NSObject` shim so the manager (a `final class @Observable`) can
    /// vend a `GADFullScreenContentDelegate`. The closures forward dismissal
    /// / failure events back to the manager so the coordinator slot is
    /// released exactly once.
    @MainActor
    private final class InterstitialPresentationDelegate: NSObject, GADFullScreenContentDelegate {
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
