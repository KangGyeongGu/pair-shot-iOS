import Foundation
import Observation
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

// MARK: - Pure session-gate helper

/// Pure decision: should the rewarded gate be shown for the supplied
/// `unlockID`?
///
/// Pulled out of `RewardedAdManager` so the policy is unit-testable
/// without spinning up the SDK. The Android v1.1.3 reference uses a
/// "watch once per session" rule for the composition-settings gate so
/// the user isn't pestered repeatedly mid-session.
enum RewardedSessionGate {
    /// - Parameters:
    ///   - unlockID: The unlock the caller wants to gate on.
    ///   - sessionUnlocks: Set of IDs already unlocked this session.
    ///   - isAdFree: Current ad-free entitlement.
    /// - Returns: `true` when the caller must present the rewarded gate
    ///   before granting access; `false` when the caller can proceed
    ///   immediately (ad-free, or already unlocked this session).
    static func shouldShowGate(
        unlockID: RewardedAdManager.UnlockID,
        sessionUnlocks: Set<RewardedAdManager.UnlockID>,
        isAdFree: Bool
    ) -> Bool {
        if isAdFree { return false }
        if sessionUnlocks.contains(unlockID) { return false }
        return true
    }
}

// MARK: - Manager

/// P6.7 — `GADRewardedAd` lifecycle manager.
///
/// Responsibilities:
/// - Pre-load a rewarded ad in the background so a tap on the gate
///   button doesn't show a spinner.
/// - Honour AdFree: no SDK call when entitled; the unlock is granted
///   immediately so the user never sees the gate.
/// - Track `sessionUnlocks` so the same gate doesn't reprompt within a
///   single foreground session.
/// - Coordinate with `FullscreenAdCoordinator` so a rewarded ad doesn't
///   collide with an Interstitial / App Open.
///
/// Per CLAUDE.md core principle 7, every ad surface must be AdFree-aware;
/// the gate lives **inside** the manager so callers don't need to remember.
@MainActor
@Observable
final class RewardedAdManager {
    /// Identifies which feature the rewarded watch unlocks. Extended as
    /// new gates are added (e.g. export-quality picker in P8).
    enum UnlockID: String, Hashable {
        /// P8.3 composition-settings detail screen (watermark / layout).
        case compositionSettings
    }

    /// Outcome of `presentForReward(...)` — surfaced to the gate view so
    /// it can decide whether to render the gated child.
    enum RewardOutcome: Equatable {
        /// User watched the ad to completion and the SDK fired the
        /// reward callback.
        case granted
        /// User dismissed the ad without earning the reward.
        case userClosed
        /// AdFree was active — no ad shown, unlock granted immediately.
        case skipped(adFree: Bool)
        /// SDK or coordinator failure. The gate stays locked.
        case failed(reason: String)
    }

    /// `true` once an ad object is loaded and ready to present.
    private(set) var isLoaded: Bool = false

    /// `true` while a load request is in-flight.
    private(set) var isLoading: Bool = false

    /// Set of unlocks already granted in the current session. Reset on
    /// process relaunch (no persistence).
    private(set) var sessionUnlocks: Set<UnlockID> = []

    #if canImport(GoogleMobileAds)
        private var ad: GADRewardedAd?
        private let presentationDelegate: RewardedPresentationDelegate
    #endif

    init() {
        #if canImport(GoogleMobileAds)
            presentationDelegate = RewardedPresentationDelegate()
        #endif
    }

    /// Pre-loads a rewarded ad if not already loaded / loading and the
    /// user is not ad-free.
    func loadIfNeeded(
        adUnitID: String? = nil,
        adFreeStore: AdFreeStore? = nil
    ) {
        if let adFreeStore, adFreeStore.isAdFree { return }
        guard !isLoaded, !isLoading else { return }
        let resolvedUnitID = adUnitID ?? AdsConfig.rewarded
        #if canImport(GoogleMobileAds)
            isLoading = true
            let request = GADRequest()
            GADRewardedAd.load(
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

    /// Attempts to present the rewarded ad for the supplied unlock.
    ///
    /// Short-circuits on:
    /// - AdFree active → `.skipped(adFree: true)` and the unlock is
    ///   inserted so subsequent `RewardedSessionGate.shouldShowGate`
    ///   calls return false.
    /// - Already unlocked this session → `.granted` immediately.
    /// - Coordinator slot busy → `.failed("coordinator-busy")`.
    /// - No ad loaded → `.failed("not-loaded")`.
    @discardableResult
    func presentForReward(
        _ unlockID: UnlockID,
        from rootViewController: UIViewController?,
        coordinator: FullscreenAdCoordinator,
        adFreeStore: AdFreeStore? = nil,
        adUnitID: String? = nil
    ) async -> RewardOutcome {
        // AdFree path: grant immediately, no SDK surface.
        if let adFreeStore, adFreeStore.isAdFree {
            sessionUnlocks.insert(unlockID)
            return .skipped(adFree: true)
        }

        // Already unlocked this session — caller can render the gated
        // child without prompting again.
        if sessionUnlocks.contains(unlockID) {
            return .granted
        }

        guard isLoaded else { return .failed(reason: "not-loaded") }
        guard await coordinator.tryAcquire() else {
            return .failed(reason: "coordinator-busy")
        }

        #if canImport(GoogleMobileAds)
            guard let ad else {
                await coordinator.release()
                return .failed(reason: "not-loaded")
            }
            // Use a continuation so we can convert the Obj-C reward
            // callback + delegate dismissal events into a single async
            // outcome the caller awaits exactly once.
            let outcome = await withCheckedContinuation { (continuation: CheckedContinuation<RewardOutcome, Never>) in
                var earned = false
                var resumed = false
                let resume: (RewardOutcome) -> Void = { result in
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: result)
                }
                presentationDelegate.onDismiss = { [weak coordinator] in
                    Task { @MainActor in
                        await coordinator?.release()
                        resume(earned ? .granted : .userClosed)
                    }
                }
                presentationDelegate.onFailToPresent = { [weak coordinator] reason in
                    Task { @MainActor in
                        await coordinator?.release()
                        resume(.failed(reason: reason))
                    }
                }
                ad.present(fromRootViewController: rootViewController) {
                    earned = true
                }
            }

            // Clean up the consumed ad and prefetch the next one.
            self.ad = nil
            isLoaded = false
            loadIfNeeded(adUnitID: adUnitID ?? AdsConfig.rewarded, adFreeStore: adFreeStore)

            if case .granted = outcome {
                sessionUnlocks.insert(unlockID)
            }
            return outcome
        #else
            // SDK not linked (CI sandbox) — the deterministic test path
            // grants the reward so callers can validate state machines.
            sessionUnlocks.insert(unlockID)
            await coordinator.release()
            return .granted
        #endif
    }

    /// Test seam: drop all session unlocks so a test can simulate a
    /// fresh session without re-instantiating the manager.
    func resetSessionUnlocksForTesting() {
        sessionUnlocks.removeAll()
    }

    /// Test seam: directly insert an unlock without going through the
    /// presentation flow.
    func grantUnlockForTesting(_ id: UnlockID) {
        sessionUnlocks.insert(id)
    }
}

#if canImport(GoogleMobileAds)
    /// Tiny `NSObject` shim so the manager (a `final class @Observable`)
    /// can vend a `GADFullScreenContentDelegate`. Closures forward the
    /// dismissal / failure events back to the manager so the coordinator
    /// slot is released and the awaited continuation resumes exactly once.
    @MainActor
    private final class RewardedPresentationDelegate: NSObject, GADFullScreenContentDelegate {
        var onDismiss: (() -> Void)?
        var onFailToPresent: ((_ reason: String) -> Void)?

        nonisolated func adDidDismissFullScreenContent(_: any GADFullScreenPresentingAd) {
            Task { @MainActor [weak self] in
                self?.onDismiss?()
            }
        }

        nonisolated func ad(
            _: any GADFullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error
        ) {
            let reason = error.localizedDescription
            Task { @MainActor [weak self] in
                self?.onFailToPresent?(reason)
            }
        }
    }
#endif
