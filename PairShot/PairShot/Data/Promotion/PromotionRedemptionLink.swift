import Foundation
import SafariServices
import UIKit

@MainActor
enum PromotionRedemptionLink {
    private static var activeCoordinator: SafariDismissCoordinator?

    static func open(
        config: CouponApiConfig,
        deviceHashProvider: DeviceHashProvider,
        onDismiss: @MainActor @escaping () -> Void = {},
    ) {
        guard let url = buildURL(config: config, deviceHash: deviceHashProvider.deviceHash()) else { return }
        guard let viewController = topViewController() else { return }
        let safari = SFSafariViewController(url: url)
        let coordinator = SafariDismissCoordinator {
            onDismiss()
            Self.activeCoordinator = nil
        }
        safari.delegate = coordinator
        Self.activeCoordinator = coordinator
        viewController.present(safari, animated: true)
    }

    nonisolated static func buildURL(config: CouponApiConfig, deviceHash: String) -> URL? {
        guard config.isEnabled else { return nil }
        guard var components = URLComponents(string: config.baseUrl + "/redeem") else { return nil }
        components.queryItems = [URLQueryItem(name: "d", value: deviceHash)]
        return components.url
    }

    private static func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return nil }
        var current = root
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }
}

@MainActor
final class SafariDismissCoordinator: NSObject, SFSafariViewControllerDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
    }

    nonisolated func safariViewControllerDidFinish(_: SFSafariViewController) {
        MainActor.assumeIsolated {
            onFinish()
        }
    }
}
