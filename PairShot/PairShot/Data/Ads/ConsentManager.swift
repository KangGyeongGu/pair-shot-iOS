import Foundation
import Observation
import UIKit
#if canImport(UserMessagingPlatform)
    import UserMessagingPlatform
#endif

@MainActor
@Observable
final class ConsentManager {
    private(set) var canRequestAds: Bool = false
    private(set) var canShowPrivacyOptionsButton: Bool = false

    func bootstrap() async {
        await requestUpdate()
        await loadAndPresentIfRequired()
        refreshFlags()
    }

    func presentPrivacyOptions() async {
        #if canImport(UserMessagingPlatform)
            guard let viewController = topViewController() else { return }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                UMPConsentForm.presentPrivacyOptionsForm(from: viewController) { _ in
                    continuation.resume()
                }
            }
            refreshFlags()
        #endif
    }

    private func requestUpdate() async {
        #if canImport(UserMessagingPlatform)
            let parameters = UMPRequestParameters()
            parameters.tagForUnderAgeOfConsent = false
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { _ in
                    continuation.resume()
                }
            }
        #endif
    }

    private func loadAndPresentIfRequired() async {
        #if canImport(UserMessagingPlatform)
            guard let viewController = topViewController() else { return }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                UMPConsentForm.loadAndPresentIfRequired(from: viewController) { _ in
                    continuation.resume()
                }
            }
        #endif
    }

    private func refreshFlags() {
        #if canImport(UserMessagingPlatform)
            canRequestAds = UMPConsentInformation.sharedInstance.canRequestAds
            canShowPrivacyOptionsButton = UMPConsentInformation.sharedInstance
                .privacyOptionsRequirementStatus == .required
        #else
            canRequestAds = true
            canShowPrivacyOptionsButton = false
        #endif
    }

    private func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        var current = root
        while let presented = current.presentedViewController { current = presented }
        return current
    }
}
