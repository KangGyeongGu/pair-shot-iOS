@preconcurrency import AVFoundation
import Foundation
import UIKit

/// Camera authorization state surfaced to the UI layer.
/// 1:1 mirror of `AVAuthorizationStatus` so callers can branch without importing AVFoundation.
enum CameraAuthorizationState {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Logical lens position for the Before/After feature.
/// Intentionally narrower than `AVCaptureDevice.Position` so the UI never has to
/// handle `.unspecified`.
enum CameraLensPosition: String, CaseIterable {
    case back
    case front
}

/// Logical flash modes Android-parity (off / on / auto / torch).
/// `off`/`on`/`auto` map to `AVCapturePhotoSettings.flashMode`.
/// `torch` toggles `device.torchMode` continuously and forces photo `flashMode = .off`.
enum CameraFlashMode: String, CaseIterable {
    case off
    case on
    case auto
    case torch

    var next: Self {
        switch self {
            case .off: .on
            case .on: .auto
            case .auto: .torch
            case .torch: .off
        }
    }
}

/// Result of a single still capture, owned by the actor and handed back to the
/// caller. JPEG bytes only — file persistence is `PhotoStorageService`'s job.
struct CapturedPhoto {
    let jpegData: Data
    let zoomFactor: Double
    let lensIdentifier: String
    let capturedAt: Date
}

/// Errors surfaced from the actor. Strings are debug-only; UI should not
/// localise these directly (P9.4 will own user-visible strings).
enum CameraSessionError: Error {
    case notConfigured
    case deviceUnavailable
    case captureFailed(String)
    case noPhotoData
}

/// Boxes a non-Sendable `AVCaptureSession` so it can be exposed via `nonisolated`
/// reference while still allowing the owning `CameraSession` actor to mutate it
/// behind serialized access.
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

    /// Currently active capture device. Nil on Simulator (no camera).
    private var activeDevice: AVCaptureDevice?
    /// Currently active input attached to the session.
    private var activeInput: AVCaptureDeviceInput?
    /// Photo output reused across captures.
    private var photoOutput: AVCapturePhotoOutput?
    /// Strong refs to in-flight capture delegates (released after `didFinishProcessingPhoto`).
    private var inFlightDelegates: [UUID: PhotoCaptureDelegate] = [:]

    /// Logical lens position currently active.
    private(set) var lensPosition: CameraLensPosition = .back
    /// Logical flash mode (last user selection). `.torch` is special — see `flashMode.next`.
    private(set) var flashMode: CameraFlashMode = .off

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

    // MARK: - Authorisation / lifecycle

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
    /// a permission UI is the caller's responsibility.
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
            configureInitialInput()
            didConfigure = true
        }

        // If configure couldn't attach an input (no camera device on this build,
        // permission revoked) we leave the session stopped — starting it
        // without inputs would have isRunning flip to true on some platforms
        // and confuse downstream UI.
        guard hasInputInternal else { return }

        guard !box.session.isRunning else { return }
        box.session.startRunning()
    }

    /// Stops the running session. Safe to call before `start()` (no-op).
    func stop() {
        guard box.session.isRunning else { return }
        box.session.stopRunning()
    }

    // MARK: - Zoom

    /// Effective minimum zoom factor for the active device.
    /// Falls back to 1.0 when no device is attached (Simulator).
    var minZoomFactor: Double {
        guard let device = activeDevice else { return 1.0 }
        return Double(device.minAvailableVideoZoomFactor)
    }

    /// Effective maximum zoom factor for the active device.
    /// Falls back to 1.0 when no device is attached (Simulator).
    var maxZoomFactor: Double {
        guard let device = activeDevice else { return 1.0 }
        return Double(device.maxAvailableVideoZoomFactor)
    }

    /// Current `videoZoomFactor`. Falls back to 1.0 on Simulator.
    var currentZoomFactor: Double {
        guard let device = activeDevice else { return 1.0 }
        return Double(device.videoZoomFactor)
    }

    /// Optional ultra-wide → wide transition factor reported by the active
    /// virtual device. Used to determine whether the 0.5x preset is meaningful.
    var ultraWideSwitchOverFactor: Double? {
        guard let device = activeDevice else { return nil }
        return device.virtualDeviceSwitchOverVideoZoomFactors.first.map { Double(truncating: $0) }
    }

    /// Smooth ramp to `factor`, clamped to device range. Used by pinch.
    func ramp(toZoomFactor factor: Double, rate: Float = 4.0) {
        guard let device = activeDevice else { return }
        let clamped = clamp(zoom: factor, device: device)
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.ramp(toVideoZoomFactor: CGFloat(clamped), withRate: rate)
        } catch {
            return
        }
    }

    /// Hard set the zoom factor (preset buttons). Cancels any in-flight ramp.
    func setZoomFactor(_ factor: Double) {
        guard let device = activeDevice else { return }
        let clamped = clamp(zoom: factor, device: device)
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isRampingVideoZoom { device.cancelVideoZoomRamp() }
            device.videoZoomFactor = CGFloat(clamped)
        } catch {
            return
        }
    }

    private func clamp(zoom: Double, device: AVCaptureDevice) -> Double {
        let minF = Double(device.minAvailableVideoZoomFactor)
        let maxF = Double(device.maxAvailableVideoZoomFactor)
        return max(minF, min(zoom, maxF))
    }

    /// Whether the given preset is selectable on the active device.
    /// 0.5x requires an ultra-wide leg in the virtual device. 1/2/5 just need to
    /// fall within the device range.
    func isPresetSupported(_ preset: ZoomPreset) -> Bool {
        guard let device = activeDevice else { return false }
        let target = preset.factor
        if target < 1.0 {
            // Need ultra-wide leg.
            guard let switchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first else {
                return false
            }
            // virtualDeviceSwitchOverVideoZoomFactors is in display-equivalent
            // *primary* device units — when the leg is ultra-wide the device's
            // minAvailableVideoZoomFactor drops below 1.0.
            _ = switchOver
            return Double(device.minAvailableVideoZoomFactor) <= target + 0.0001
        }
        return target <= Double(device.maxAvailableVideoZoomFactor)
    }

    // MARK: - Lens switching

    /// Toggles between front/back wide-angle. Picks `.builtInDualWideCamera` /
    /// `.builtInTripleCamera` when present so the 0.5x preset works.
    func switchLens(to position: CameraLensPosition) {
        guard didConfigure else { return }

        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        guard let device = preferredDevice(for: avPosition) else { return }

        box.session.beginConfiguration()
        defer { box.session.commitConfiguration() }

        if let activeInput {
            box.session.removeInput(activeInput)
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if box.session.canAddInput(input) {
                box.session.addInput(input)
                activeInput = input
                activeDevice = device
                lensPosition = position
                hasInputInternal = true
            }
        } catch {
            return
        }
    }

    /// Picks the best available camera for `position`. Prefers virtual devices
    /// that span ultra-wide → tele so the 0.5x preset is meaningful when present.
    private func preferredDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera,
        ]
        for type in preferredTypes {
            if let device = AVCaptureDevice.default(type, for: .video, position: position) {
                return device
            }
        }
        return nil
    }

    // MARK: - Flash

    /// Sets the user-facing flash mode. For `.torch` we additionally toggle the
    /// continuous torch lamp; for the photo modes we only persist the choice
    /// and let `capturePhoto()` apply it on each shot.
    func setFlashMode(_ mode: CameraFlashMode) {
        flashMode = mode
        applyTorchState()
    }

    /// Cycles flash → flash.next.
    func cycleFlashMode() -> CameraFlashMode {
        let next = flashMode.next
        setFlashMode(next)
        return next
    }

    private func applyTorchState() {
        guard let device = activeDevice else { return }
        guard device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            switch flashMode {
                case .torch:
                    if device.isTorchModeSupported(.on) {
                        device.torchMode = .on
                    }

                case .off, .on, .auto:
                    if device.isTorchModeSupported(.off) {
                        device.torchMode = .off
                    }
            }
        } catch {
            return
        }
    }

    // MARK: - Focus / exposure

    /// Tap to focus. `point` is in device-coordinate space (0..1, 0..1) — the
    /// caller is responsible for converting from view space via
    /// `previewLayer.captureDevicePointConverted(fromLayerPoint:)`.
    func focus(at point: CGPoint) {
        guard let device = activeDevice else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusPointOfInterestSupported,
               device.isFocusModeSupported(.autoFocus)
            {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported,
               device.isExposureModeSupported(.autoExpose)
            {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
        } catch {
            return
        }
    }

    /// EV target bias range supported by the active device. Returns `nil` on
    /// Simulator. UI clamps the drag delta against this range.
    var exposureBiasRange: ClosedRange<Float>? {
        guard let device = activeDevice else { return nil }
        return device.minExposureTargetBias ... device.maxExposureTargetBias
    }

    /// Apply EV bias. Caller pre-clamps to `exposureBiasRange`.
    func setExposureBias(_ bias: Float) async {
        guard let device = activeDevice else { return }
        do {
            try device.lockForConfiguration()
            let clamped = max(device.minExposureTargetBias, min(bias, device.maxExposureTargetBias))
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                device.setExposureTargetBias(clamped) { _ in
                    cont.resume()
                }
            }
            device.unlockForConfiguration()
        } catch {
            return
        }
    }

    // MARK: - Capture

    /// Captures a still photo using the current flash/zoom/lens state.
    /// Returns the JPEG bytes plus capture metadata; persisting to disk is the
    /// caller's responsibility (`PhotoStorageService.saveBeforeJPEG`).
    func capturePhoto() async throws -> CapturedPhoto {
        guard let photoOutput, let device = activeDevice else {
            throw CameraSessionError.notConfigured
        }

        let settings = AVCapturePhotoSettings()
        if device.hasFlash {
            switch flashMode {
                case .auto: settings.flashMode = .auto
                case .on: settings.flashMode = .on
                case .off, .torch: settings.flashMode = .off
            }
        }

        let zoom = Double(device.videoZoomFactor)
        let lens = lensIdentifier(for: device)

        return try await withCheckedThrowingContinuation { cont in
            let id = UUID()
            let delegate = PhotoCaptureDelegate { [weak self] result in
                guard let self else { return }
                Task { await self.removeDelegate(id: id) }
                switch result {
                    case let .success(data):
                        cont.resume(returning: CapturedPhoto(
                            jpegData: data,
                            zoomFactor: zoom,
                            lensIdentifier: lens,
                            capturedAt: .now
                        ))

                    case let .failure(err):
                        cont.resume(throwing: err)
                }
            }
            inFlightDelegates[id] = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func removeDelegate(id: UUID) {
        inFlightDelegates.removeValue(forKey: id)
    }

    private func lensIdentifier(for device: AVCaptureDevice) -> String {
        // `AVCaptureDevice.DeviceType` has a `rawValue` like
        // "AVCaptureDeviceTypeBuiltInWideAngleCamera". Strip the prefix for
        // a stable but compact identifier. Combine with position so front/back
        // are distinguishable.
        let raw = device.deviceType.rawValue
        let stripped = raw.replacingOccurrences(of: "AVCaptureDeviceType", with: "")
        let position = switch device.position {
            case .back: "back"
            case .front: "front"
            case .unspecified: "unspecified"
            @unknown default: "unknown"
        }
        return "\(stripped).\(position)"
    }

    // MARK: - Initial configuration

    private func configureInitialInput() {
        let session = box.session
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Walk the preferred devices and stop at the first one that produces
        // an input the session can actually accept. This guards against
        // simulator quirks where higher-tier virtual devices answer nil/unusable.
        let candidates: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera,
        ]
        for type in candidates {
            guard let device = AVCaptureDevice.default(type, for: .video, position: .back) else {
                continue
            }
            guard let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input)
            else {
                continue
            }
            session.addInput(input)
            activeInput = input
            activeDevice = device
            lensPosition = .back
            hasInputInternal = true
            break
        }

        // If we couldn't attach any input (e.g. permission revoked mid-flight),
        // bail out before adding a useless photo output.
        guard hasInputInternal else { return }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            photoOutput = output
        }
    }
}

/// Logical zoom presets surfaced to the UI. `factor` is the raw
/// `videoZoomFactor` we apply to the active device.
enum ZoomPreset: String, CaseIterable {
    case ultraWide
    case wide
    case tele2x
    case tele5x

    var factor: Double {
        switch self {
            case .ultraWide: 0.5
            case .wide: 1.0
            case .tele2x: 2.0
            case .tele5x: 5.0
        }
    }

    var label: String {
        switch self {
            case .ultraWide: "0.5x"
            case .wide: "1x"
            case .tele2x: "2x"
            case .tele5x: "5x"
        }
    }
}

/// Bridges `AVCapturePhotoCaptureDelegate` (Objective-C) to a Swift completion
/// closure. Lives only for the duration of one shot.
/// `nonisolated` so the AVFoundation delivery thread can call back without
/// hopping onto the main actor.
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<Data, CameraSessionError>) -> Void

    nonisolated init(completion: @escaping @Sendable (Result<Data, CameraSessionError>) -> Void) {
        self.completion = completion
    }

    nonisolated func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(.captureFailed(error.localizedDescription)))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(.noPhotoData))
            return
        }
        completion(.success(data))
    }
}
