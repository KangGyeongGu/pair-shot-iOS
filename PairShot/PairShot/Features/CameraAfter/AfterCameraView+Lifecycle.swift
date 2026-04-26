@preconcurrency import AVFoundation
import SwiftUI

/// Audit-C — extension housing the AVFoundation camera-permission probe
/// + ghost-image loading helpers. Lifted out of ``AfterCameraView`` so
/// the parent stays under the 250-line cap.
extension AfterCameraView {
    /// Probe the camera authorization status, requesting access on
    /// `.notDetermined`. Mirrors ``BeforeCameraView/checkCameraPermission``
    /// — duplication is intentional because each view owns its own
    /// granted-state binding.
    static func resolveCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                true

            case .notDetermined:
                await AVCaptureDevice.requestAccess(for: .video)

            case .denied, .restricted:
                false

            @unknown default:
                false
        }
    }
}
