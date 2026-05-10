import AppTrackingTransparency
import Foundation
import Observation
import OSLog
import SwiftUI
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
        private var inflightLoader: GADAdLoader?
    #endif

    init(trackingService: TrackingAuthorizationService? = nil) {
        self.trackingService = trackingService
        super.init()
    }

    func prefetch(
        count: Int,
        adUnitID: String? = nil,
        adFreeStore: AdFreeStore? = nil
    ) {
        if let adFreeStore, adFreeStore.isAdFree { return }
        guard count > 0 else { return }
        guard !isLoading else { return }
        let resolvedUnitID = adUnitID ?? AdsConfig.native
        #if canImport(GoogleMobileAds)
            let attStatus = trackingService?.currentStatus ?? .notDetermined
            let request = AdRequestBuilder.build(attStatus: attStatus)
            isLoading = true
            AppLogger.ads.debug("Native prefetch requested count=\(count, privacy: .public)")
            let multipleOptions = GADMultipleAdsAdLoaderOptions()
            multipleOptions.numberOfAds = count
            let loader = GADAdLoader(
                adUnitID: resolvedUnitID,
                rootViewController: BannerAdView.resolveRootViewController(),
                adTypes: [GADAdLoaderAdType.native],
                options: [multipleOptions]
            )
            loader.delegate = self
            inflightLoader = loader
            loader.load(request)
        #else
            isLoading = false
        #endif
    }

    func dequeue(adFreeStore: AdFreeStore? = nil) -> Any? {
        if let adFreeStore, adFreeStore.isAdFree { return nil }
        guard !loadedAds.isEmpty else {
            prefetch(count: 1, adFreeStore: adFreeStore)
            return nil
        }
        let ad = loadedAds.removeFirst()
        if loadedAds.count < 2 {
            prefetch(count: 5, adFreeStore: adFreeStore)
        }
        return ad
    }

    var loadedCount: Int {
        loadedAds.count
    }
}

#if canImport(GoogleMobileAds)
    extension NativeAdLoader: GADNativeAdLoaderDelegate {
        nonisolated func adLoader(
            _: GADAdLoader,
            didReceive nativeAd: GADNativeAd
        ) {
            Task { @MainActor [weak self] in
                self?.loadedAds.append(nativeAd)
            }
        }

        nonisolated func adLoader(
            _: GADAdLoader,
            didFailToReceiveAdWithError error: Error
        ) {
            let description = error.localizedDescription
            Task { @MainActor [weak self] in
                AppLogger.ads.error("Native load failed: \(description, privacy: .public)")
                self?.lastErrorDescription = description
                self?.isLoading = false
                self?.inflightLoader = nil
            }
        }

        nonisolated func adLoaderDidFinishLoading(_: GADAdLoader) {
            Task { @MainActor [weak self] in
                self?.isLoading = false
                self?.inflightLoader = nil
            }
        }
    }
#endif

#if canImport(GoogleMobileAds)
    private struct NativeAdRepresentable: UIViewRepresentable {
        let nativeAd: GADNativeAd

        func makeUIView(context _: Context) -> GADNativeAdView {
            let adView = GADNativeAdView()

            let icon = UIImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.contentMode = .scaleAspectFit
            icon.layer.cornerRadius = 6
            icon.clipsToBounds = true

            let headline = UILabel()
            headline.translatesAutoresizingMaskIntoConstraints = false
            headline.font = .preferredFont(forTextStyle: .headline)
            headline.numberOfLines = 2

            let body = UILabel()
            body.translatesAutoresizingMaskIntoConstraints = false
            body.font = .preferredFont(forTextStyle: .footnote)
            body.numberOfLines = 3
            body.textColor = .secondaryLabel

            var ctaConfig = UIButton.Configuration.filled()
            ctaConfig.baseBackgroundColor = .systemBlue
            ctaConfig.baseForegroundColor = .white
            ctaConfig.cornerStyle = .small
            ctaConfig.contentInsets = NSDirectionalEdgeInsets(
                top: 6, leading: 10, bottom: 6, trailing: 10
            )
            let cta = UIButton(configuration: ctaConfig)
            cta.translatesAutoresizingMaskIntoConstraints = false
            cta.isUserInteractionEnabled = false

            adView.addSubview(icon)
            adView.addSubview(headline)
            adView.addSubview(body)
            adView.addSubview(cta)

            adView.iconView = icon
            adView.headlineView = headline
            adView.bodyView = body
            adView.callToActionView = cta

            NSLayoutConstraint.activate([
                icon.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),
                icon.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
                icon.widthAnchor.constraint(equalToConstant: 36),
                icon.heightAnchor.constraint(equalToConstant: 36),

                headline.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),
                headline.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
                headline.trailingAnchor.constraint(
                    equalTo: adView.trailingAnchor,
                    constant: -8
                ),

                body.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 4),
                body.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
                body.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -8),

                cta.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -8),
                cta.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -8),
            ])

            adView.nativeAd = nativeAd
            return adView
        }

        func updateUIView(_ adView: GADNativeAdView, context _: Context) {
            adView.nativeAd = nativeAd
            (adView.headlineView as? UILabel)?.text = nativeAd.headline
            (adView.bodyView as? UILabel)?.text = nativeAd.body
            if let cta = adView.callToActionView as? UIButton {
                var config = cta.configuration ?? UIButton.Configuration.filled()
                config.title = nativeAd.callToAction
                cta.configuration = config
            }
            if let iconView = adView.iconView as? UIImageView {
                iconView.image = nativeAd.icon?.image
            }
        }
    }
#endif
