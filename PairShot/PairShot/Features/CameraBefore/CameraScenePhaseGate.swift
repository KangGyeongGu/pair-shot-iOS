import Foundation
import SwiftUI

/// Audit-B — pure scene-phase decision used by ``BeforeCameraView`` and
/// ``AfterCameraView`` to decide whether to stop / restart their
/// `CameraSession` actor on a given lifecycle transition.
///
/// Pulling the policy out keeps it unit-testable without spinning up
/// a SwiftUI scene + AVFoundation session, and gives both camera views
/// a single source of truth for the rule.
///
/// Policy:
/// - `.background` → call ``CameraSessionAction/stop``.
/// - `.active`     → call ``CameraSessionAction/start`` (the view's
///                   own `.task` runs once at first appear; the start
///                   here covers re-entry from background).
/// - `.inactive`   → no-op (transient interruption — leaving the
///                   session up means the user returns to a live
///                   preview without a perceivable hiccup).
enum CameraSessionAction: Equatable {
    /// Tear the AVCaptureSession down so the camera is released.
    case stop
    /// Bring the AVCaptureSession back up.
    case start
}

enum CameraScenePhaseGate {
    /// - Parameter newPhase: Phase the scene just transitioned to.
    /// - Returns: The action to perform, or `nil` for transitions
    ///   that should leave the session untouched (`.inactive`,
    ///   `@unknown`).
    static func action(for newPhase: ScenePhase) -> CameraSessionAction? {
        switch newPhase {
            case .background: .stop
            case .active: .start
            case .inactive: nil
            @unknown default: nil
        }
    }
}
