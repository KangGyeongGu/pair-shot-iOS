import Foundation
import SafariServices
import UIKit

@MainActor
enum CouponRedemptionLink {
    static func open(config: CouponApiConfig, deviceHashProvider: DeviceHashProvider) {
        guard config.isEnabled else { return }
        let hash = deviceHashProvider.deviceHash()
        guard var components = URLComponents(string: config.baseUrl + "/redeem") else { return }
        components.queryItems = [URLQueryItem(name: "d", value: hash)]
        guard let url = components.url else { return }
        guard let viewController = topViewController() else { return }
        let safari = SFSafariViewController(url: url)
        viewController.present(safari, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
        var current = root
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }
}
