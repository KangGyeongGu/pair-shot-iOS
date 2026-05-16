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
final class NativeAdLoader: NSObject {
    private(set) var loadedAds: [Any] = []

    private(set) var isLoading: Bool = false

    private(set) var lastErrorDescription: String?

    private let trackingService: TrackingAuthorizationService?

    #if canImport(GoogleMobileAds)
        private var inflightLoader: AdLoader?
    #endif

    init(trackingService: TrackingAuthorizationService? = nil) {
        self.trackingService = trackingService
        super.init()
    }

    func prefetch(
        count: Int,
        adUnitID: String? = nil,
        promotionStore: PromotionStore? = nil,
        subscriptionStore: SubscriptionStore? = nil,
    ) {
        if AdSuppression.isSuppressed(promotionStore: promotionStore, subscriptionStore: subscriptionStore) { return }
        guard count > 0 else { return }
        guard !isLoading else { return }
        let resolvedUnitID = adUnitID ?? AdsConfig.native
        #if canImport(GoogleMobileAds)
            let attStatus = trackingService?.currentStatus ?? .notDetermined
            let request = AdRequestBuilder.build(attStatus: attStatus)
            isLoading = true
            AppLogger.ads.debug("Native prefetch requested count=\(count, privacy: .public)")
            let multipleOptions = MultipleAdsAdLoaderOptions()
            multipleOptions.numberOfAds = count
            let loader = AdLoader(
                adUnitID: resolvedUnitID,
                rootViewController: BannerAdView.resolveRootViewController(),
                adTypes: [AdLoaderAdType.native],
                options: [multipleOptions],
            )
            loader.delegate = self
            inflightLoader = loader
            loader.load(request)
        #else
            isLoading = false
        #endif
    }

    func dequeue(
        promotionStore: PromotionStore? = nil,
        subscriptionStore: SubscriptionStore? = nil,
    ) -> Any? {
        if AdSuppression
            .isSuppressed(promotionStore: promotionStore, subscriptionStore: subscriptionStore) { return nil }
        guard !loadedAds.isEmpty else {
            prefetch(count: 1, promotionStore: promotionStore, subscriptionStore: subscriptionStore)
            return nil
        }
        let ad = loadedAds.removeFirst()
        if loadedAds.count < 2 {
            prefetch(count: 5, promotionStore: promotionStore, subscriptionStore: subscriptionStore)
        }
        return ad
    }
}

#if canImport(GoogleMobileAds)
    extension NativeAdLoader: NativeAdLoaderDelegate {
        nonisolated func adLoader(
            _: AdLoader,
            didReceive nativeAd: NativeAd,
        ) {
            Task { @MainActor [weak self] in
                self?.loadedAds.append(nativeAd)
            }
        }

        nonisolated func adLoader(
            _: AdLoader,
            didFailToReceiveAdWithError error: Error,
        ) {
            let description = error.localizedDescription
            Task { @MainActor [weak self] in
                AppLogger.ads.error("Native load failed: \(description, privacy: .public)")
                self?.lastErrorDescription = description
                self?.isLoading = false
                self?.inflightLoader = nil
            }
        }

        nonisolated func adLoaderDidFinishLoading(_: AdLoader) {
            Task { @MainActor [weak self] in
                self?.isLoading = false
                self?.inflightLoader = nil
            }
        }
    }
#endif
