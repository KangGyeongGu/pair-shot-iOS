import AppTrackingTransparency
import Foundation
import Observation
import OSLog
import UIKit
#if canImport(GoogleMobileAds)
    @preconcurrency import GoogleMobileAds
#endif

enum AppOpenAdGate {
    nonisolated static let defaultMinimumInterval: TimeInterval = 60

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
    private let trackingService: TrackingAuthorizationService?

    #if canImport(GoogleMobileAds)
        private var ad: GADAppOpenAd?
        private let presentationDelegate: AppOpenPresentationDelegate
    #endif

    init(
        minimumInterval: TimeInterval = AppOpenAdGate.defaultMinimumInterval,
        trackingService: TrackingAuthorizationService? = nil
    ) {
        self.minimumInterval = minimumInterval
        self.trackingService = trackingService
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
            let attStatus = trackingService?.currentStatus ?? .notDetermined
            let request = AdRequestBuilder.build(attStatus: attStatus)
            isLoading = true
            AppLogger.ads.debug("AppOpen load requested")
            GADAppOpenAd.load(
                withAdUnitID: resolvedUnitID,
                request: request
            ) { [weak self] ad, error in
                let adBox = AppOpenAdBox(ad: ad)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    isLoading = false
                    if let resolvedAd = adBox.ad {
                        self.ad = resolvedAd
                        isLoaded = true
                        resolvedAd.fullScreenContentDelegate = presentationDelegate
                        AppLogger.ads.debug("AppOpen loaded")
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
        if !isLoaded, !isLoading {
            loadIfNeeded(adUnitID: adUnitID, adFreeStore: adFreeStore)
        }
        if !isLoaded {
            let deadline = Date().addingTimeInterval(5)
            while !isLoaded, Date() < deadline {
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard isLoaded else { return false }
        }
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
            AppLogger.ads.debug("AppOpen presented")
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
    nonisolated private final class AppOpenAdBox: @unchecked Sendable {
        let ad: GADAppOpenAd?
        init(ad: GADAppOpenAd?) {
            self.ad = ad
        }
    }

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
