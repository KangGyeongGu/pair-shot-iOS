@preconcurrency import AVFoundation
import Foundation

/// Camera authorization state surfaced to the UI layer.
/// 1:1 mirror of `AVAuthorizationStatus` so callers can branch without importing AVFoundation.
enum CameraAuthorizationState: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Boxes a non-Sendable `AVCaptureSession` so it can be exposed via `nonisolated`
/// reference while still allowing the owning `CameraSession` actor to mutate it
/// behind serialized access.
///
/// Swift 6 strict concurrency forbids storing a non-Sendable value as a stored
/// property of an actor without ceremony. The preview layer needs the same
/// `AVCaptureSession` reference that the actor configures, so we wrap it.
private final class CaptureSessionBox: @unchecked Sendable {
    nonisolated(unsafe) let session: AVCaptureSession
    nonisolated init() {
        session = AVCaptureSession()
    }
}

/// Owns one `AVCaptureSession` for a single camera feature (Before or After).
///
/// Lifecycle:
/// ```
/// .task { await session.start() }
/// .onDisappear { Task { await session.stop() } }
/// ```
///
/// On the iOS Simulator there is no back camera, so `configure()` silently skips
/// device input wiring; the preview just shows a black layer. Real-device preview
/// is verified manually in P9.
actor CameraSession {
    private let box = CaptureSessionBox()
    private var didConfigure = false
    private var hasInputInternal = false

    /// Underlying `AVCaptureSession`. Exposed `nonisolated` so the SwiftUI
    /// preview layer can attach without hopping onto the actor.
    nonisolated var captureSession: AVCaptureSession {
        box.session
    }

    /// Whether a back-camera `AVCaptureDeviceInput` was successfully attached
    /// during `configure()`. False on the Simulator and on devices that report
    /// no `.builtInWideAngleCamera` for `.back`.
    var hasInput: Bool {
        hasInputInternal
    }

    /// `true` after `start()` brings the session up and before `stop()` tears it down.
    var isRunning: Bool {
        box.session.isRunning
    }

    init() {}

    /// Returns the current camera authorization state without prompting.
    func authorizationState() -> CameraAuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    /// Brings the session up. Requests permission on first call when status is
    /// `.notDetermined`. Silently returns on `.denied` / `.restricted`; surfacing
    /// a permission UI is the caller's responsibility (planned in P2.6).
    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { return }
        case .denied, .restricted:
            return
        @unknown default:
            return
        }

        if !didConfigure {
            configure()
            didConfigure = true
        }

        guard !box.session.isRunning else { return }
        box.session.startRunning()
    }

    /// Stops the running session. Safe to call before `start()` (no-op).
    func stop() {
        guard box.session.isRunning else { return }
        box.session.stopRunning()
    }

    // MARK: - Private

    /// Configures the back-wide-angle device + photo output once.
    /// On the Simulator the device lookup returns nil — we silently skip and
    /// leave `hasInputInternal == false` so the UI can still show a black preview.
    private func configure() {
        let session = box.session
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                hasInputInternal = true
            }
        } catch {
            return
        }

        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
    }
}
