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
    @Environment(TrackingAuthorizationService.self) private var tracking

    let adUnitID: String
    @State private var hasRequestedATT = false
    @State private var hasArmed = false

    init(adUnitID: String = AdsConfig.banner) {
        self.adUnitID = adUnitID
    }

    var body: some View {
        if BannerAdGate.shouldShow(isAdFree: adFreeStore.isAdFree) {
            let width = BannerAdView.currentBannerWidth()
            let height = BannerAdSize.adaptiveHeight(width: width)
            Group {
                if hasArmed {
                    BannerAdView(
                        adUnitID: adUnitID,
                        width: width,
                        attStatus: tracking.currentStatus
                    )
                    .frame(width: width, height: height)
                    .frame(maxWidth: .infinity, maxHeight: height, alignment: .top)
                    .clipped()
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: height, alignment: .top)
                }
            }
            .task {
                if !hasArmed {
                    try? await Task.sleep(for: .milliseconds(900))
                    hasArmed = true
                }
                guard !hasRequestedATT else { return }
                hasRequestedATT = true
                _ = await tracking.requestIfUndetermined()
            }
        }
    }
}

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat
    let attStatus: ATTrackingManager.AuthorizationStatus

    init(
        adUnitID: String = AdsConfig.banner,
        width: CGFloat,
        attStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    ) {
        self.adUnitID = adUnitID
        self.width = width
        self.attStatus = attStatus
    }

    #if canImport(GoogleMobileAds)
        func makeUIView(context: Context) -> GADBannerView {
            let view = GADBannerView(adSize: BannerAdSize.adaptive(width: width))
            view.adUnitID = adUnitID
            view.rootViewController = Self.resolveRootViewController()
            context.coordinator.lastWidth = width
            let request = AdRequestBuilder.build(attStatus: attStatus)
            AppLogger.ads.debug("Banner load requested width=\(width, privacy: .public)")
            view.load(request)
            return view
        }

        func updateUIView(_ uiView: GADBannerView, context: Context) {
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
        static func resolveTopPresentedViewController() -> UIViewController? {
            var current = resolveRootViewController()
            while let presented = current?.presentedViewController {
                current = presented
            }
            return current
        }

        @MainActor
        static func currentBannerWidth() -> CGFloat {
            let scene = UIApplication.shared.connectedScenes
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
    #else
        func makeUIView(context _: Context) -> UIView {
            UIView()
        }

        func updateUIView(_: UIView, context _: Context) {}
    #endif
}

enum BannerAdSize {
    static let fallbackWidth: CGFloat = 320

    static let fallbackHeight: CGFloat = 50

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

        @MainActor
        static func adaptiveHeight(width: CGFloat) -> CGFloat {
            guard width > 0 else { return fallbackHeight }
            let height = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width).size.height
            return height > 0 ? height : fallbackHeight
        }
    #else
        @MainActor
        static func adaptiveHeight(width _: CGFloat) -> CGFloat {
            fallbackHeight
        }
    #endif
}
