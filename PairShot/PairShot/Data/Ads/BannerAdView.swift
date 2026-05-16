import AppTrackingTransparency
import OSLog
import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
    import GoogleMobileAds
#endif

enum BannerAdGate {
    static func shouldShow(isAdFree: Bool, isPro: Bool = false) -> Bool {
        !AdSuppression.isSuppressed(isAdFree: isAdFree, isPro: isPro)
    }
}

struct BannerAdSlot: View {
    @Environment(Membership.self) private var membership
    @Environment(TrackingAuthorizationService.self) private var tracking

    let adUnitID: String

    var body: some View {
        if BannerAdGate.shouldShow(
            isAdFree: membership.adFreeBySolePromotion,
            isPro: membership.proIsActive,
        ) {
            let width = BannerAdView.currentBannerWidth()
            let height = BannerAdSize.adaptiveHeight(width: width)
            BannerAdView(
                width: width,
                adUnitID: adUnitID,
                attStatus: tracking.currentStatus,
            )
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .top)
            .clipped()
        }
    }

    init(adUnitID: String = AdsConfig.banner) {
        self.adUnitID = adUnitID
    }
}

struct BannerAdView: UIViewRepresentable {
    #if canImport(GoogleMobileAds)
        @MainActor
        final class Coordinator {
            var lastWidth: CGFloat = 0
        }
    #endif

    let adUnitID: String
    let width: CGFloat
    let attStatus: ATTrackingManager.AuthorizationStatus

    init(
        width: CGFloat,
        adUnitID: String = AdsConfig.banner,
        attStatus: ATTrackingManager.AuthorizationStatus = .notDetermined,
    ) {
        self.adUnitID = adUnitID
        self.width = width
        self.attStatus = attStatus
    }

    #if canImport(GoogleMobileAds)
        func makeUIView(context: Context) -> BannerView {
            let view = BannerView(adSize: BannerAdSize.adaptive(width: width))
            view.adUnitID = adUnitID
            view.rootViewController = Self.resolveRootViewController()
            context.coordinator.lastWidth = width
            let request = AdRequestBuilder.build(attStatus: attStatus)
            AppLogger.ads.debug("Banner load requested width=\(width, privacy: .public)")
            view.load(request)
            return view
        }

        func updateUIView(_ uiView: BannerView, context: Context) {
            if uiView.rootViewController == nil {
                uiView.rootViewController = Self.resolveRootViewController()
            }
            if BannerAdSize.shouldReload(previous: context.coordinator.lastWidth, current: width) {
                context.coordinator.lastWidth = width
                uiView.adSize = BannerAdSize.adaptive(width: width)
                let request = AdRequestBuilder.build(attStatus: attStatus)
                AppLogger.ads.debug("Banner reload width=\(width, privacy: .public)")
                uiView.load(request)
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }
    #else
        func makeUIView(context _: Context) -> UIView {
            UIView()
        }

        func updateUIView(_: UIView, context _: Context) {}
    #endif

    #if canImport(GoogleMobileAds)
        @MainActor
        static func resolveRootViewController() -> UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController
        }

        @MainActor
        static func resolveTopPresentedViewController() -> UIViewController? {
            var current = resolveRootViewController()
            while let presented = current?.presentedViewController {
                current = presented
            }
            return current
        }

        @MainActor
        static func currentBannerWidth() -> CGFloat {
            let scene =
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first { $0.activationState == .foregroundActive }
                    ?? UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first
            let window = scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first
            if let width = window?.bounds.width, width > 0 {
                return width
            }
            if let sceneWidth = scene?.coordinateSpace.bounds.width, sceneWidth > 0 {
                return sceneWidth
            }
            return BannerAdSize.fallbackWidth
        }
    #endif
}

enum BannerAdSize {
    static let fallbackWidth: CGFloat = 320

    static let fallbackHeight: CGFloat = 50

    static let inlineMaxHeight: CGFloat = 60

    static let reloadThreshold: CGFloat = 1.0

    static func shouldReload(previous: CGFloat, current: CGFloat) -> Bool {
        guard previous > 0 else { return current > 0 }
        return abs(current - previous) >= reloadThreshold
    }

    #if canImport(GoogleMobileAds)
        @MainActor
        static func adaptive(width: CGFloat) -> AdSize {
            guard width > 0 else { return AdSizeBanner }
            return inlineAdaptiveBanner(width: width, maxHeight: inlineMaxHeight)
        }

        @MainActor
        static func adaptiveHeight(width: CGFloat) -> CGFloat {
            guard width > 0 else { return fallbackHeight }
            let height = inlineAdaptiveBanner(width: width, maxHeight: inlineMaxHeight).size.height
            return height > 0 ? height : fallbackHeight
        }
    #else
        @MainActor
        static func adaptiveHeight(width _: CGFloat) -> CGFloat {
            fallbackHeight
        }
    #endif
}
