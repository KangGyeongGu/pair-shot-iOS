import Foundation
import SafariServices
import UIKit

@MainActor
enum CouponRedemptionLink {
    static func open(config: CouponApiConfig, deviceHashProvider: DeviceHashProvider) {
        guard let url = buildURL(config: config, deviceHash: deviceHashProvider.deviceHash()) else { return }
        guard let viewController = topViewController() else { return }
        let safari = SFSafariViewController(url: url)
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
