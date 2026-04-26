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
/// Audit-D — switched to **adaptive banner** sizing. The previous
/// `GADAdSizeBanner` (320×50) wastes space on iPad and on landscape
/// iPhones. ``BannerAdSize.adaptive(width:)`` delegates to
/// `currentOrientationAnchoredAdaptiveBanner(width:)` per Google's v11
/// guidance — the SDK returns the right height for the current
/// orientation, defaulting back to a sane fallback when the width is
/// unknown (e.g. the very first `makeUIView` call before SwiftUI has
/// laid out the parent).
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    init(adUnitID: String = AdsConfig.banner) {
        self.adUnitID = adUnitID
    }

    #if canImport(GoogleMobileAds)
        func makeUIView(context: Context) -> GADBannerView {
            // Initial width = current key window width. SwiftUI hasn't
            // measured the host yet so this is the best estimate we
            // have; ``updateUIView(_:context:)`` re-applies whenever
            // the parent's width changes.
            let initialWidth = Self.currentBannerWidth()
            let view = GADBannerView(adSize: BannerAdSize.adaptive(width: initialWidth))
            view.adUnitID = adUnitID
            view.rootViewController = Self.resolveRootViewController()
            context.coordinator.lastWidth = initialWidth
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

        func updateUIView(_ uiView: GADBannerView, context: Context) {
            // Re-attach the root view controller in case the window changed
            // (e.g. multi-scene). The banner caches its delegate / ad.
            if uiView.rootViewController == nil {
                uiView.rootViewController = Self.resolveRootViewController()
            }
            // Audit-D — recompute adaptive size when the parent width
            // changes (rotation, split-view resize). We only re-load
            // the request if the size really shifted; SwiftUI calls
            // updateUIView on unrelated state changes too.
            let width = Self.currentBannerWidth()
            if BannerAdSize.shouldReload(previous: context.coordinator.lastWidth, current: width) {
                context.coordinator.lastWidth = width
                uiView.adSize = BannerAdSize.adaptive(width: width)
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        /// Tracks the last width applied so we don't churn the SDK
        /// when SwiftUI calls `updateUIView` for unrelated reasons.
        @MainActor
        final class Coordinator {
            var lastWidth: CGFloat = 0
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

        /// Width to feed into the adaptive banner size. Falls back to
        /// 320pt when no key window is available (e.g. extremely early
        /// scene boot) so the SDK still gets a non-zero hint.
        @MainActor
        static func currentBannerWidth() -> CGFloat {
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
            return window?.bounds.width ?? BannerAdSize.fallbackWidth
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

// MARK: - Adaptive size policy

/// Pure helpers for the adaptive banner sizing decision (Audit-D).
/// Extracted so the width-change reload policy is unit-testable
/// without touching UIKit.
enum BannerAdSize {
    /// Width used when the key window isn't available yet — covers
    /// the standard 320×50 banner so the SDK has something to load
    /// against on the very first frame.
    static let fallbackWidth: CGFloat = 320

    /// Hysteresis threshold (in points) below which a width change is
    /// ignored. Avoids reloading the banner for sub-pixel layout
    /// jitter on iPads where SwiftUI may report rotated bounds before
    /// the system rotation animation completes.
    static let reloadThreshold: CGFloat = 1.0

    /// Should we re-apply the adaptive `adSize` for the new width?
    /// True when this is the first measurement (`previous == 0`) or
    /// when the width changed by more than ``reloadThreshold``.
    static func shouldReload(previous: CGFloat, current: CGFloat) -> Bool {
        guard previous > 0 else { return current > 0 }
        return abs(current - previous) >= reloadThreshold
    }

    #if canImport(GoogleMobileAds)
        /// Resolves the AdMob v11 adaptive banner size for `width`,
        /// or the legacy `GADAdSizeBanner` when `width` is unusable
        /// (zero / negative — should never happen in practice but
        /// defensive).
        @MainActor
        static func adaptive(width: CGFloat) -> GADAdSize {
            guard width > 0 else { return GADAdSizeBanner }
            return GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        }
    #endif
}
