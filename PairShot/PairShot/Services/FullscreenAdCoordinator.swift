import Foundation
import SwiftUI

/// Serialises fullscreen ad presentations.
///
/// Interstitial / App Open / Rewarded ads are all "fullscreen" — only one
/// can ever be on screen at a time. Without a coordinator we can race two
/// surfaces against each other (e.g. an App Open arriving from
/// `scenePhase = .active` while an Interstitial fires from a sheet
/// dismissal), causing one ad to silently fail to present and burning the
/// impression cap.
///
/// Usage:
/// ```swift
/// guard await coordinator.tryAcquire() else { return false }
/// defer { Task { await coordinator.release() } }
/// ad.present(fromRootViewController: rvc)
/// ```
///
/// `actor` isolation guarantees `tryAcquire` is atomic: two concurrent
/// callers cannot both observe `isShowing == false` and both flip it to
/// true. Callers that lose the race must skip — never queue / retry —
/// so we don't accidentally chain two fullscreen ads back-to-back.
actor FullscreenAdCoordinator {
    /// `true` while a fullscreen ad has been acquired but not yet released.
    /// Exposed for diagnostics / tests; production callers should use the
    /// `tryAcquire` / `release` API rather than reading this directly.
    private(set) var isShowing: Bool = false

    init() {}

    /// Atomically attempts to acquire the fullscreen slot.
    /// - Returns: `true` if the caller now owns the slot and must call
    ///   `release()` after the ad is dismissed; `false` if another
    ///   surface is currently showing — caller should skip the ad request.
    func tryAcquire() -> Bool {
        guard !isShowing else { return false }
        isShowing = true
        return true
    }

    /// Releases the slot. Idempotent — calling release when not showing
    /// is a no-op rather than a precondition failure, because
    /// `GADFullScreenContentDelegate` callbacks can occasionally arrive
    /// in surprising order (e.g. didFail then didDismiss).
    func release() {
        isShowing = false
    }
}

extension EnvironmentValues {
    @Entry var fullscreenAdCoordinator: FullscreenAdCoordinator = .init()
}
