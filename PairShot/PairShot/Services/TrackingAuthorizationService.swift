import AppTrackingTransparency
import Foundation
import Observation

/// Abstraction over `ATTrackingManager` so callers can be unit-tested with
/// a fake implementation (the system framework is not testable directly —
/// `requestTrackingAuthorization` requires a foreground app).
///
/// The protocol intentionally mirrors `ATTrackingManager`'s shape so the
/// production `SystemTrackingAuthorizationProvider` is a one-line forward.
protocol TrackingAuthorizationProviding: Sendable {
    /// Synchronous current status — wraps
    /// `ATTrackingManager.trackingAuthorizationStatus`.
    var currentStatus: ATTrackingManager.AuthorizationStatus { get }

    /// Async permission request — wraps
    /// `ATTrackingManager.requestTrackingAuthorization(completionHandler:)`.
    /// Implementations must be safe to call from any actor.
    func requestAuthorization() async -> ATTrackingManager.AuthorizationStatus
}

/// Production implementation of `TrackingAuthorizationProviding` backed by
/// the real `ATTrackingManager`.
struct SystemTrackingAuthorizationProvider: TrackingAuthorizationProviding {
    var currentStatus: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    func requestAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

/// Holds the latest ATT authorization status and exposes a single entry
/// point — `requestIfUndetermined()` — for callers (e.g. the first ad
/// surface, P6.5 BannerAdView). Once the user has decided once, iOS will
/// not show the prompt again, and we just return the cached decision.
///
/// `MainActor` because the underlying `ATTrackingManager.requestTracking…`
/// must be invoked on the main thread per Apple guidance, and because the
/// observable state drives SwiftUI.
@MainActor
@Observable
final class TrackingAuthorizationService {
    /// Most recently observed status. Updated after every
    /// `requestIfUndetermined()` call and on `refresh()`.
    private(set) var currentStatus: ATTrackingManager.AuthorizationStatus

    private let provider: TrackingAuthorizationProviding

    /// Production initialiser — uses the system `ATTrackingManager`.
    convenience init() {
        self.init(provider: SystemTrackingAuthorizationProvider())
    }

    /// Test seam: inject a `TrackingAuthorizationProviding` fake.
    init(provider: TrackingAuthorizationProviding) {
        self.provider = provider
        currentStatus = provider.currentStatus
    }

    /// Re-reads the current status from the underlying provider without
    /// triggering a permission prompt. Useful when returning from
    /// Settings.
    func refresh() {
        currentStatus = provider.currentStatus
    }

    /// If the status is `.notDetermined`, asks the user. Otherwise
    /// returns the cached decision immediately. Always returns the
    /// resulting status (never `nil`).
    @discardableResult
    func requestIfUndetermined() async -> ATTrackingManager.AuthorizationStatus {
        let snapshot = provider.currentStatus
        guard snapshot == .notDetermined else {
            currentStatus = snapshot
            return snapshot
        }
        let result = await provider.requestAuthorization()
        currentStatus = result
        return result
    }

    /// `true` when the user has explicitly granted tracking — the only
    /// case where the SDK is allowed to use the IDFA. Both `.denied` and
    /// `.restricted` produce non-personalised ads at the SDK layer.
    var isAuthorized: Bool {
        currentStatus == .authorized
    }
}
