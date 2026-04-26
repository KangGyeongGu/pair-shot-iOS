import Foundation
import Observation
import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

// MARK: - Pure insertion strategy

/// Pure decision: at which 0-based positions in a list of `n` pairs
/// should a native-ad cell be inserted?
///
/// The Android v1.1.3 reference inserts an ad after every 6th pair, so
/// in a list of 14 pairs the indices `[5, 11]` (0-based) become ad
/// slots. The list is rendered as `[pair, pair, pair, pair, pair, ad,
/// pair, pair, pair, pair, pair, ad, pair, pair]` — total 16 cells.
///
/// `interval` defaults to 6; `n` may be 0 / negative (returns empty).
/// `interval` ≤ 0 is also treated as "no ads" rather than crashing —
/// keeps the gallery view defensive against settings glitches.
enum NativeAdInsertionStrategy {
    static func indices(forPairCount n: Int, interval: Int = 6) -> [Int] {
        guard n > 0, interval > 0 else { return [] }
        var slots: [Int] = []
        var slot = interval - 1 // first ad after `interval` pairs (0-based)
        while slot < n {
            slots.append(slot)
            slot += interval
        }
        return slots
    }
}

// MARK: - Loader

/// P6.8 — `GADAdLoader` + `GADNativeAd` prefetch pool.
///
/// Pre-loads a small batch of native ads so the gallery `LazyVGrid`
/// can vend an ad for any insertion slot without a network round-trip
/// at scroll time. The pool is round-robin'd by `adFor(index:)`, so the
/// same ad will repeat in a long list of slots — matching AdMob's own
/// guidance for native-ad reuse in lists.
///
/// AdFree path: `prefetch` is a no-op so no SDK call is made and no
/// space is reserved by the gallery (the gallery filters out ad slots
/// when `isAdFree`, in addition to this layer).
@MainActor
@Observable
final class NativeAdLoader: NSObject {
    /// Currently loaded ads — round-robin'd by `adFor(index:)`.
    private(set) var loadedAds: [Any] = []

    /// `true` while at least one in-flight load request is outstanding.
    private(set) var isLoading: Bool = false

    /// Most recent `adLoader:didFailToReceiveAdWithError:` description.
    /// Surfaced for diagnostic logging; the gallery does not show it.
    private(set) var lastErrorDescription: String?

    #if canImport(GoogleMobileAds)
        /// The loader is retained for the duration of the request and
        /// released when the delegate callback fires. Keeping a single
        /// loader hot would also work, but the simpler one-shot form
        /// avoids edge cases around overlapping requests.
        private var inflightLoader: GADAdLoader?
    #endif

    override init() {
        super.init()
    }

    /// Pre-loads up to `count` native ads. Skips when AdFree is active.
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
            isLoading = true
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
            loader.load(GADRequest())
        #else
            isLoading = false
        #endif
    }

    /// Round-robins the loaded pool. Returns `nil` when no ads have
    /// loaded yet — the caller should render a placeholder cell or
    /// skip the slot entirely.
    func adFor(index: Int) -> Any? {
        guard !loadedAds.isEmpty else { return nil }
        let safeIndex = ((index % loadedAds.count) + loadedAds.count) % loadedAds.count
        return loadedAds[safeIndex]
    }

    /// Number of ads currently in the pool. Pure read, exposed for tests.
    var loadedCount: Int {
        loadedAds.count
    }

    /// Test seam: drop the pool so a test can validate empty-pool branches.
    func resetForTesting() {
        loadedAds.removeAll()
        isLoading = false
        lastErrorDescription = nil
    }

    /// Test seam: inject preloaded ad placeholders without an SDK call.
    /// Tests pass `Any` opaque tokens; the strategy / round-robin code
    /// doesn't care about the concrete type.
    func injectAdsForTesting(_ ads: [Any]) {
        loadedAds = ads
        isLoading = false
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

// MARK: - Native ad cell

/// Minimal SwiftUI wrapper around `GADNativeAdView`. Renders headline /
/// body / CTA / icon — the four assets we care about for an in-list
/// promotion. Falls back to an inert placeholder when the SDK isn't
/// linked or the supplied ad token isn't a `GADNativeAd` (e.g. test
/// injection of opaque `Any`).
struct NativeAdCell: View {
    let ad: Any?

    var body: some View {
        #if canImport(GoogleMobileAds)
            if let nativeAd = ad as? GADNativeAd {
                NativeAdRepresentable(nativeAd: nativeAd)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                placeholder
            }
        #else
            placeholder
        #endif
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
            Text(String(localized: "광고"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#if canImport(GoogleMobileAds)
    /// `GADNativeAdView` UIKit bridge. Lays out headline / body / icon /
    /// CTA in a vertical stack — the parent `NativeAdCell` clips to a
    /// 1:1 aspect ratio so it visually matches a thumbnail.
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
            cta.isUserInteractionEnabled = false // SDK manages tap

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
