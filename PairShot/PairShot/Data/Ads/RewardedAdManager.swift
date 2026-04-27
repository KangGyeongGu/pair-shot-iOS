import AppTrackingTransparency
import Foundation
import Observation
import OSLog
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

enum RewardedSessionGate {
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

@MainActor
@Observable
final class RewardedAdManager {
    enum UnlockID: String, Hashable {
        case compositionSettings
        case watermarkSettings
    }

    enum RewardOutcome: Equatable {
        case granted
        case userClosed
        case skipped(adFree: Bool)
        case failed(reason: String)
    }

    private(set) var isLoaded: Bool = false

    private(set) var isLoading: Bool = false

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

    func loadIfNeeded(
        adUnitID: String? = nil,
        adFreeStore: AdFreeStore? = nil
    ) {
        if let adFreeStore, adFreeStore.isAdFree { return }
        guard !isLoaded, !isLoading else { return }
        let resolvedUnitID = adUnitID ?? AdsConfig.rewarded
        #if canImport(GoogleMobileAds)
            guard let request = AdRequestBuilder.build(
                isAdFree: adFreeStore?.isAdFree ?? false,
                attStatus: ATTrackingManager.trackingAuthorizationStatus
            ) else { return }
            isLoading = true
            AppLogger.ads.debug("Rewarded load requested")
            GADRewardedAd.load(
                withAdUnitID: resolvedUnitID,
                request: request
            ) { [weak self] ad, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    isLoading = false
                    if let ad {
                        self.ad = ad
                        isLoaded = true
                        ad.fullScreenContentDelegate = presentationDelegate
                        AppLogger.ads.debug("Rewarded loaded")
                    } else {
                        self.ad = nil
                        isLoaded = false
                        if let error {
                            AppLogger.ads.error(
                                "Rewarded load failed: \(error.localizedDescription, privacy: .public)"
                            )
                        }
                    }
                }
            }
        #endif
    }

    @discardableResult
    func presentForReward(
        _ unlockID: UnlockID,
        from rootViewController: UIViewController?,
        coordinator: FullscreenAdCoordinator,
        adFreeStore: AdFreeStore? = nil,
        adUnitID: String? = nil
    ) async -> RewardOutcome {
        if let adFreeStore, adFreeStore.isAdFree {
            sessionUnlocks.insert(unlockID)
            return .skipped(adFree: true)
        }

        if sessionUnlocks.contains(unlockID) {
            return .granted
        }

        guard isLoaded else { return .failed(reason: "not-loaded") }
        if let rootViewController, rootViewController.presentedViewController != nil {
            AppLogger.ads.warning("Rewarded skipped — root already presenting another view controller")
            return .failed(reason: "already-presenting")
        }
        guard await coordinator.tryAcquire() else {
            return .failed(reason: "coordinator-busy")
        }

        #if canImport(GoogleMobileAds)
            guard let ad else {
                await coordinator.release()
                return .failed(reason: "not-loaded")
            }
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
                AppLogger.ads.debug("Rewarded presented")
                ad.present(fromRootViewController: rootViewController) {
                    earned = true
                }
            }

            self.ad = nil
            isLoaded = false
            loadIfNeeded(adUnitID: adUnitID ?? AdsConfig.rewarded, adFreeStore: adFreeStore)

            if case .granted = outcome {
                sessionUnlocks.insert(unlockID)
            }
            return outcome
        #else
            sessionUnlocks.insert(unlockID)
            await coordinator.release()
            return .granted
        #endif
    }

    func resetSessionUnlocksForTesting() {
        sessionUnlocks.removeAll()
    }

    func grantUnlockForTesting(_ id: UnlockID) {
        sessionUnlocks.insert(id)
    }
}

#if canImport(GoogleMobileAds)
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
                AppLogger.ads.error("Rewarded failed to present: \(reason, privacy: .public)")
                self?.onFailToPresent?(reason)
            }
        }
    }
#endif
