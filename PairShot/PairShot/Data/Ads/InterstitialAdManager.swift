import AppTrackingTransparency
import Foundation
import Observation
import OSLog
import UIKit
#if canImport(GoogleMobileAds)
    @preconcurrency import GoogleMobileAds
#endif

@MainActor
@Observable
final class InterstitialAdManager {
    struct PresentContext {
        let rootViewController: UIViewController?
        let coordinator: FullscreenAdCoordinator
        let adFreeStore: AdFreeStore?
        let subscriptionStore: SubscriptionStore?
        let adUnitID: String?
        let now: Date
        let onFinished: @MainActor () -> Void
    }

    nonisolated static let cooldownSeconds: TimeInterval = 5.0

    private(set) var isLoaded: Bool = false

    private(set) var isLoading: Bool = false

    private(set) var lastShownAt: Date?

    private let trackingService: TrackingAuthorizationService?

    #if canImport(GoogleMobileAds)
        private var ad: GADInterstitialAd?
        private let presentationDelegate: InterstitialPresentationDelegate
    #endif

    init(
        trackingService: TrackingAuthorizationService? = nil
    ) {
        self.trackingService = trackingService
        #if canImport(GoogleMobileAds)
            presentationDelegate = InterstitialPresentationDelegate()
        #endif
    }

    func loadIfNeeded(
        adUnitID: String? = nil,
        adFreeStore: AdFreeStore? = nil,
        subscriptionStore: SubscriptionStore? = nil
    ) {
        if AdSuppression.isSuppressed(adFreeStore: adFreeStore, subscriptionStore: subscriptionStore) { return }
        guard !isLoaded, !isLoading else { return }
        let resolvedUnitID = adUnitID ?? AdsConfig.interstitial
        #if canImport(GoogleMobileAds)
            let attStatus = trackingService?.currentStatus ?? .notDetermined
            let request = AdRequestBuilder.build(attStatus: attStatus)
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
    func showIfAvailable(
        from rootViewController: UIViewController?,
        coordinator: FullscreenAdCoordinator,
        adFreeStore: AdFreeStore? = nil,
        subscriptionStore: SubscriptionStore? = nil,
        adUnitID: String? = nil,
        now: Date = .now,
        onFinished: @escaping @MainActor () -> Void
    ) async -> Bool {
        let context = PresentContext(
            rootViewController: rootViewController,
            coordinator: coordinator,
            adFreeStore: adFreeStore,
            subscriptionStore: subscriptionStore,
            adUnitID: adUnitID,
            now: now,
            onFinished: onFinished
        )
        guard shouldShow(context: context) else {
            return false
        }
        guard await coordinator.tryAcquire() else {
            onFinished()
            return false
        }
        return await presentAd(context: context)
    }

    private func shouldShow(context: PresentContext) -> Bool {
        if AdSuppression.isSuppressed(
            adFreeStore: context.adFreeStore,
            subscriptionStore: context.subscriptionStore
        ) {
            context.onFinished()
            return false
        }
        if let lastShownAt, context.now.timeIntervalSince(lastShownAt) < Self.cooldownSeconds {
            context.onFinished()
            loadIfNeeded(
                adUnitID: context.adUnitID,
                adFreeStore: context.adFreeStore,
                subscriptionStore: context.subscriptionStore
            )
            return false
        }
        guard isLoaded else {
            context.onFinished()
            loadIfNeeded(
                adUnitID: context.adUnitID,
                adFreeStore: context.adFreeStore,
                subscriptionStore: context.subscriptionStore
            )
            return false
        }
        return true
    }

    private func presentAd(context: PresentContext) async -> Bool {
        #if canImport(GoogleMobileAds)
            guard let ad else {
                await context.coordinator.release()
                context.onFinished()
                loadIfNeeded(
                    adUnitID: context.adUnitID,
                    adFreeStore: context.adFreeStore,
                    subscriptionStore: context.subscriptionStore
                )
                return false
            }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                var resumed = false
                let resume: () -> Void = {
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume()
                }
                presentationDelegate.onDismiss = { [weak self] in
                    Task { @MainActor in
                        await context.coordinator.release()
                        self?.lastShownAt = Date()
                        self?.ad = nil
                        self?.isLoaded = false
                        self?.loadIfNeeded(
                            adUnitID: context.adUnitID,
                            adFreeStore: context.adFreeStore,
                            subscriptionStore: context.subscriptionStore
                        )
                        context.onFinished()
                        resume()
                    }
                }
                presentationDelegate.onFailToPresent = { [weak self] in
                    Task { @MainActor in
                        await context.coordinator.release()
                        self?.ad = nil
                        self?.isLoaded = false
                        self?.loadIfNeeded(
                            adUnitID: context.adUnitID,
                            adFreeStore: context.adFreeStore,
                            subscriptionStore: context.subscriptionStore
                        )
                        context.onFinished()
                        resume()
                    }
                }
                AppLogger.ads.debug("Interstitial showIfAvailable presented")
                ad.present(fromRootViewController: context.rootViewController)
            }
            return true
        #else
            await context.coordinator.release()
            lastShownAt = context.now
            context.onFinished()
            return true
        #endif
    }
}

@MainActor
extension InterstitialAdManager {
    static func runGated(
        manager: InterstitialAdManager?,
        adFreeStore: AdFreeStore?,
        subscriptionStore: SubscriptionStore?,
        coordinator: FullscreenAdCoordinator?,
        work: @escaping @MainActor () async -> Void
    ) async {
        guard let manager, let coordinator else {
            await work()
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task { @MainActor in
                await manager.showIfAvailable(
                    from: BannerAdView.resolveTopPresentedViewController(),
                    coordinator: coordinator,
                    adFreeStore: adFreeStore,
                    subscriptionStore: subscriptionStore
                ) {
                    Task { @MainActor in
                        await work()
                        continuation.resume()
                    }
                }
            }
        }
    }
}

#if canImport(GoogleMobileAds)
    private final nonisolated class InterstitialAdBox: @unchecked Sendable {
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
