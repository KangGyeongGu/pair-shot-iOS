import AppTrackingTransparency
import Foundation
import Observation
import OSLog
import UIKit
#if canImport(GoogleMobileAds)
    @preconcurrency import GoogleMobileAds
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
    nonisolated static let cooldownSeconds: TimeInterval = 5.0

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
            AppLogger.ads.debug("Interstitial load requested")
            GADInterstitialAd.load(
                withAdUnitID: resolvedUnitID,
                request: request
            ) { [weak self] ad, error in
                let adBox = InterstitialAdBox(ad: ad)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    isLoading = false
                    if let resolvedAd = adBox.ad {
                        self.ad = resolvedAd
                        isLoaded = true
                        resolvedAd.fullScreenContentDelegate = presentationDelegate
                        AppLogger.ads.debug("Interstitial loaded")
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
            AppLogger.ads.debug("Interstitial presented")
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

    @discardableResult
    func showIfAvailable(
        from rootViewController: UIViewController?,
        adFreeStore: AdFreeStore,
        coordinator: FullscreenAdCoordinator,
        adUnitID: String? = nil,
        now: Date = .now,
        onFinished: @escaping @MainActor () -> Void
    ) async -> Bool {
        if adFreeStore.isAdFree {
            onFinished()
            return false
        }

        if let lastShownAt, now.timeIntervalSince(lastShownAt) < Self.cooldownSeconds {
            onFinished()
            loadIfNeeded(adUnitID: adUnitID, adFreeStore: adFreeStore)
            return false
        }

        guard isLoaded else {
            onFinished()
            loadIfNeeded(adUnitID: adUnitID, adFreeStore: adFreeStore)
            return false
        }

        guard await coordinator.tryAcquire() else {
            onFinished()
            return false
        }

        #if canImport(GoogleMobileAds)
            guard let ad else {
                await coordinator.release()
                onFinished()
                loadIfNeeded(adUnitID: adUnitID, adFreeStore: adFreeStore)
                return false
            }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                var resumed = false
                let resume: () -> Void = {
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume()
                }
                presentationDelegate.onDismiss = { [weak coordinator, weak self] in
                    Task { @MainActor in
                        await coordinator?.release()
                        self?.lastShownAt = Date()
                        self?.ad = nil
                        self?.isLoaded = false
                        self?.loadIfNeeded(adUnitID: adUnitID, adFreeStore: adFreeStore)
                        onFinished()
                        resume()
                    }
                }
                presentationDelegate.onFailToPresent = { [weak coordinator, weak self] in
                    Task { @MainActor in
                        await coordinator?.release()
                        self?.ad = nil
                        self?.isLoaded = false
                        self?.loadIfNeeded(adUnitID: adUnitID, adFreeStore: adFreeStore)
                        onFinished()
                        resume()
                    }
                }
                AppLogger.ads.debug("Interstitial showIfAvailable presented")
                ad.present(fromRootViewController: rootViewController)
            }
            return true
        #else
            await coordinator.release()
            lastShownAt = now
            onFinished()
            return true
        #endif
    }
}

#if canImport(GoogleMobileAds)
    nonisolated private final class InterstitialAdBox: @unchecked Sendable {
        let ad: GADInterstitialAd?
        init(ad: GADInterstitialAd?) {
            self.ad = ad
        }
    }

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
