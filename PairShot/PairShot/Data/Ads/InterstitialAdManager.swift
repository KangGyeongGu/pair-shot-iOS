import AppTrackingTransparency
import Foundation
import Observation
import OSLog
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

enum InterstitialFrequencyGate {
    static func shouldPresent(
        now: Date,
        lastShownAt: Date?,
        minimumInterval: TimeInterval
    ) -> Bool {
        guard let lastShownAt else { return true }
        return now.timeIntervalSince(lastShownAt) >= minimumInterval
    }
}

@MainActor
@Observable
final class InterstitialAdManager {
    nonisolated static let defaultMinimumInterval: TimeInterval = 300

    private(set) var isLoaded: Bool = false

    private(set) var isLoading: Bool = false

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

    func loadIfNeeded(
        adUnitID: String? = nil,
        adFreeStore: AdFreeStore? = nil
    ) {
        if let adFreeStore, adFreeStore.isAdFree { return }
        guard !isLoaded, !isLoading else { return }
        let resolvedUnitID = adUnitID ?? AdsConfig.interstitial
        #if canImport(GoogleMobileAds)
            guard let request = AdRequestBuilder.build(
                isAdFree: adFreeStore?.isAdFree ?? false,
                attStatus: ATTrackingManager.trackingAuthorizationStatus
            ) else { return }
            isLoading = true
            AppLogger.ads.info("Interstitial load requested")
            GADInterstitialAd.load(
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
                        AppLogger.ads.info("Interstitial loaded")
                    } else {
                        self.ad = nil
                        isLoaded = false
                        if let error {
                            AppLogger.ads.error(
                                "Interstitial load failed: \(error.localizedDescription, privacy: .public)"
                            )
                        }
                    }
                }
            }
        #endif
    }

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
            presentationDelegate.onDismiss = { [weak coordinator] in
                Task { await coordinator?.release() }
            }
            presentationDelegate.onFailToPresent = { [weak coordinator] in
                Task { await coordinator?.release() }
            }
            ad.present(fromRootViewController: rootViewController)
            AppLogger.ads.info("Interstitial presented")
            lastShownAt = now
            self.ad = nil
            isLoaded = false
            loadIfNeeded(adUnitID: adUnitID ?? AdsConfig.interstitial, adFreeStore: adFreeStore)
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
            didFailToPresentFullScreenContentWithError error: Error
        ) {
            let description = error.localizedDescription
            Task { @MainActor [weak self] in
                AppLogger.ads.error("Interstitial failed to present: \(description, privacy: .public)")
                self?.onFailToPresent?()
            }
        }
    }
#endif
