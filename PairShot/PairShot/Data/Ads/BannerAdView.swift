import AppTrackingTransparency
import OSLog
import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

enum BannerAdGate {
    static func shouldShow(isAdFree: Bool) -> Bool {
        !isAdFree
    }
}

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
                .background(Color.black.opacity(0.001))
        }
    }
}

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    init(adUnitID: String = AdsConfig.banner) {
        self.adUnitID = adUnitID
    }

    #if canImport(GoogleMobileAds)
        func makeUIView(context: Context) -> GADBannerView {
            let initialWidth = Self.currentBannerWidth()
            let view = GADBannerView(adSize: BannerAdSize.adaptive(width: initialWidth))
            view.adUnitID = adUnitID
            view.rootViewController = Self.resolveRootViewController()
            context.coordinator.lastWidth = initialWidth
            let request = AdRequestBuilder.build(
                isAdFree: false,
                attStatus: ATTrackingManager.trackingAuthorizationStatus
            ) ?? GADRequest()
            AppLogger.ads.info("Banner load requested")
            view.load(request)
            return view
        }

        func updateUIView(_ uiView: GADBannerView, context: Context) {
            if uiView.rootViewController == nil {
                uiView.rootViewController = Self.resolveRootViewController()
            }
            let width = Self.currentBannerWidth()
            if BannerAdSize.shouldReload(previous: context.coordinator.lastWidth, current: width) {
                context.coordinator.lastWidth = width
                uiView.adSize = BannerAdSize.adaptive(width: width)
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        @MainActor
        final class Coordinator {
            var lastWidth: CGFloat = 0
        }

        @MainActor
        static func resolveRootViewController() -> UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController
        }

        @MainActor
        static func currentBannerWidth() -> CGFloat {
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
            return window?.bounds.width ?? BannerAdSize.fallbackWidth
        }
    #else
        func makeUIView(context _: Context) -> UIView {
            UIView()
        }

        func updateUIView(_: UIView, context _: Context) {}
    #endif
}

enum BannerAdSize {
    static let fallbackWidth: CGFloat = 320

    static let reloadThreshold: CGFloat = 1.0

    static func shouldReload(previous: CGFloat, current: CGFloat) -> Bool {
        guard previous > 0 else { return current > 0 }
        return abs(current - previous) >= reloadThreshold
    }

    #if canImport(GoogleMobileAds)
        @MainActor
        static func adaptive(width: CGFloat) -> GADAdSize {
            guard width > 0 else { return GADAdSizeBanner }
            return GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        }
    #endif
}
