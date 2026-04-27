import AppTrackingTransparency
import Foundation
import Observation
import OSLog
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

enum AppOpenAdGate {
    nonisolated static let defaultMinimumInterval: TimeInterval = 240

    static func shouldPresent(
        lastShownAt: Date?,
        now: Date,
        minimumInterval: TimeInterval = defaultMinimumInterval
    ) -> Bool {
        guard let lastShownAt else { return true }
        return now.timeIntervalSince(lastShownAt) >= minimumInterval
    }
}

@MainActor
@Observable
final class AppOpenAdManager {
    private(set) var isLoaded: Bool = false

    private(set) var isLoading: Bool = false

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

    func loadIfNeeded(
        adUnitID: String? = nil,
        adFreeStore: AdFreeStore? = nil
    ) {
        if let adFreeStore, adFreeStore.isAdFree { return }
        guard !isLoaded, !isLoading else { return }
        let resolvedUnitID = adUnitID ?? AdsConfig.appOpen
        #if canImport(GoogleMobileAds)
            guard let request = AdRequestBuilder.build(
                isAdFree: adFreeStore?.isAdFree ?? false,
                attStatus: ATTrackingManager.trackingAuthorizationStatus
            ) else { return }
            isLoading = true
            AppLogger.ads.info("AppOpen load requested")
            GADAppOpenAd.load(
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
                        AppLogger.ads.info("AppOpen loaded")
                    } else {
                        self.ad = nil
                        isLoaded = false
                        if let error {
                            AppLogger.ads.error(
                                "AppOpen load failed: \(error.localizedDescription, privacy: .public)"
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
        guard AppOpenAdGate.shouldPresent(
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
            AppLogger.ads.info("AppOpen presented")
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
            didFailToPresentFullScreenContentWithError error: Error
        ) {
            let description = error.localizedDescription
            Task { @MainActor [weak self] in
                AppLogger.ads.error("AppOpen failed to present: \(description, privacy: .public)")
                self?.onFailToPresent?()
            }
        }
    }
#endif
