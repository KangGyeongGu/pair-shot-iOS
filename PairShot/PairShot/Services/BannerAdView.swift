import AppTrackingTransparency
import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

// MARK: - Pure gate

/// Pure decision: should a banner ad surface render at all?
///
/// The view-level guard (`if BannerAdGate.shouldShow(isAdFree:)`) is
/// preferred over hiding `GADBannerView.isHidden` because it prevents
/// the ad request from ever being fired, which (a) avoids unnecessary
/// network and (b) prevents ATT being triggered for ad-free users.
enum BannerAdGate {
    static func shouldShow(isAdFree: Bool) -> Bool {
        !isAdFree
    }
}

// MARK: - SwiftUI surface

/// Convenience SwiftUI wrapper that combines the AdFree guard with the
/// underlying `GADBannerView` representable. Drop this into any layout
/// surface that should host a banner — typically as a `safeAreaInset`
/// sibling of the main content. When AdFree is active the entire view
/// collapses to `EmptyView()` so no SDK call is made and no layout
/// space is reserved.
struct BannerAdSlot: View {
    @Environment(AdFreeStore.self) private var adFreeStore

    let adUnitID: String

    init(adUnitID: String = AdsConfig.banner) {
        self.adUnitID = adUnitID
    }

    var body: some View {
        if BannerAdGate.shouldShow(isAdFree: adFreeStore.isAdFree) {
            BannerAdView(adUnitID: adUnitID)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.001)) // hit-testable container
        }
    }
}

/// `GADBannerView` wrapped as a `UIViewRepresentable`.
///
/// Standard 320x50 banner — adaptive sizes are deferred to a later pass
/// (P9) once the design system has fixed banner placement. The banner
/// triggers a load on first `makeUIView`; SwiftUI does not destroy the
/// view across normal state updates, so subsequent `updateUIView` calls
/// are no-ops.
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    init(adUnitID: String = AdsConfig.banner) {
        self.adUnitID = adUnitID
    }

    #if canImport(GoogleMobileAds)
        func makeUIView(context _: Context) -> GADBannerView {
            let view = GADBannerView(adSize: GADAdSizeBanner)
            view.adUnitID = adUnitID
            view.rootViewController = Self.resolveRootViewController()
            // Audit-B — `BannerAdSlot` already gated the AdFree path,
            // so by the time we land in `makeUIView` we know
            // `isAdFree == false`. We still funnel through
            // `AdRequestBuilder` so the npa extra is attached when
            // ATT is denied / restricted, mirroring every other ad
            // surface.
            let request = AdRequestBuilder.build(
                isAdFree: false,
                attStatus: ATTrackingManager.trackingAuthorizationStatus
            ) ?? GADRequest()
            view.load(request)
            return view
        }

        func updateUIView(_ uiView: GADBannerView, context _: Context) {
            // Re-attach the root view controller in case the window changed
            // (e.g. multi-scene). The banner caches its delegate / ad.
            if uiView.rootViewController == nil {
                uiView.rootViewController = Self.resolveRootViewController()
            }
        }

        /// Resolves the active scene's root view controller without touching
        /// `UIApplication.shared.windows` (deprecated on iOS 15+). Returning
        /// `nil` is acceptable — the SDK falls back to the top view
        /// controller of the main window.
        @MainActor
        static func resolveRootViewController() -> UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController
        }
    #else
        /// Fallback when the SDK isn't linked (e.g. in CI environments
        /// without package resolution). Renders an inert UIView so the
        /// SwiftUI host is still well-typed.
        func makeUIView(context _: Context) -> UIView {
            UIView()
        }

        func updateUIView(_: UIView, context _: Context) {}
    #endif
}
