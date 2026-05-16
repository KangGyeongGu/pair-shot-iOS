import AppTrackingTransparency
import Foundation
import Observation
import UIKit
#if canImport(GoogleMobileAds)
    @preconcurrency import GoogleMobileAds
#endif

enum RewardedSessionGate {
    static func shouldShowGate(
        unlockID: RewardedAdManager.UnlockID,
        sessionUnlocks: Set<RewardedAdManager.UnlockID>,
        isAdFree: Bool,
        isPro: Bool = false,
    ) -> Bool {
        if AdSuppression.isSuppressed(isAdFree: isAdFree, isPro: isPro) { return false }
        if sessionUnlocks.contains(unlockID) { return false }
        return true
    }
}

@MainActor
@Observable
final class RewardedAdManager {
    enum UnlockID: String, Hashable {
        case compositionSettings
        case watermarkSettings
    }

    enum RewardOutcome: Equatable {
        case granted
        case userClosed
        case failed(reason: String)
    }

    private(set) var isLoaded: Bool = false

    private(set) var isLoading: Bool = false

    private(set) var sessionUnlocks: Set<UnlockID> = []

    private let trackingService: TrackingAuthorizationService?
    private let tutorialCoordinator: TutorialCoordinator?

    #if canImport(GoogleMobileAds)
        private var ad: RewardedAd?
        private let presentationDelegate: RewardedPresentationDelegate
    #endif

    init(
        trackingService: TrackingAuthorizationService? = nil,
        tutorialCoordinator: TutorialCoordinator? = nil,
    ) {
        self.trackingService = trackingService
        self.tutorialCoordinator = tutorialCoordinator
        #if canImport(GoogleMobileAds)
            presentationDelegate = RewardedPresentationDelegate()
        #endif
    }

    func loadIfNeeded(
        adUnitID: String? = nil,
        promotionStore: PromotionStore? = nil,
        subscriptionStore: SubscriptionStore? = nil,
    ) {
        if AdSuppression.isSuppressed(
            promotionStore: promotionStore,
            subscriptionStore: subscriptionStore,
            tutorialCoordinator: tutorialCoordinator,
        ) { return }
        guard !isLoaded, !isLoading else { return }
        let resolvedUnitID = adUnitID ?? AdsConfig.rewarded
        #if canImport(GoogleMobileAds)
            let attStatus = trackingService?.currentStatus ?? .notDetermined
            let request = AdRequestBuilder.build(attStatus: attStatus)
            isLoading = true
            RewardedAd.load(
                with: resolvedUnitID,
                request: request,
            ) { [weak self] ad, _ in
                let adBox = RewardedAdBox(ad: ad)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    isLoading = false
                    if let resolvedAd = adBox.ad {
                        self.ad = resolvedAd
                        isLoaded = true
                        resolvedAd.fullScreenContentDelegate = presentationDelegate
                    } else {
                        self.ad = nil
                        isLoaded = false
                    }
                }
            }
        #endif
    }

    @discardableResult
    func presentForReward(
        _ unlockID: UnlockID,
        from rootViewController: UIViewController?,
        coordinator: FullscreenAdCoordinator,
        promotionStore: PromotionStore? = nil,
        subscriptionStore: SubscriptionStore? = nil,
        adUnitID: String? = nil,
    ) async -> RewardOutcome {
        if AdSuppression.isSuppressed(
            promotionStore: promotionStore,
            subscriptionStore: subscriptionStore,
            tutorialCoordinator: tutorialCoordinator,
        ) {
            sessionUnlocks.insert(unlockID)
            return .granted
        }

        if sessionUnlocks.contains(unlockID) {
            return .granted
        }

        guard isLoaded else { return .failed(reason: "not-loaded") }
        if let rootViewController, rootViewController.presentedViewController != nil {
            return .failed(reason: "already-presenting")
        }
        guard await coordinator.tryAcquire() else {
            return .failed(reason: "coordinator-busy")
        }

        #if canImport(GoogleMobileAds)
            guard let ad else {
                await coordinator.release()
                return .failed(reason: "not-loaded")
            }
            let outcome = await withCheckedContinuation { (continuation: CheckedContinuation<RewardOutcome, Never>) in
                var earned = false
                var resumed = false
                let resume: (RewardOutcome) -> Void = { result in
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: result)
                }
                presentationDelegate.onDismiss = { [weak coordinator] in
                    Task { @MainActor in
                        await coordinator?.release()
                        resume(earned ? .granted : .userClosed)
                    }
                }
                presentationDelegate.onFailToPresent = { [weak coordinator] reason in
                    Task { @MainActor in
                        await coordinator?.release()
                        resume(.failed(reason: reason))
                    }
                }
                ad.present(from: rootViewController) {
                    earned = true
                }
            }

            self.ad = nil
            isLoaded = false
            loadIfNeeded(
                adUnitID: adUnitID ?? AdsConfig.rewarded,
                promotionStore: promotionStore,
                subscriptionStore: subscriptionStore,
            )

            if case .granted = outcome {
                sessionUnlocks.insert(unlockID)
            }
            return outcome
        #else
            sessionUnlocks.insert(unlockID)
            await coordinator.release()
            return .granted
        #endif
    }
}

#if canImport(GoogleMobileAds)
    private final nonisolated class RewardedAdBox: @unchecked Sendable {
        let ad: RewardedAd?
        init(ad: RewardedAd?) {
            self.ad = ad
        }
    }

    @MainActor
    private final class RewardedPresentationDelegate: NSObject, FullScreenContentDelegate {
        var onDismiss: (() -> Void)?
        var onFailToPresent: ((_ reason: String) -> Void)?

        nonisolated func adDidDismissFullScreenContent(_: any FullScreenPresentingAd) {
            Task { @MainActor [weak self] in
                self?.onDismiss?()
            }
        }

        nonisolated func ad(
            _: any FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error,
        ) {
            let reason = error.localizedDescription
            Task { @MainActor [weak self] in
                self?.onFailToPresent?(reason)
            }
        }
    }
#endif
