@preconcurrency import AVFoundation
import Foundation
import UIKit

enum CameraAuthorizationState {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum CameraLensPosition: String, CaseIterable {
    case back
    case front
}

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

struct CapturedPhoto {
    let jpegData: Data
    let zoomFactor: Double
    let lensIdentifier: String
    let capturedAt: Date
}

enum CameraSessionError: Error {
    case notConfigured
    case deviceUnavailable
    case captureFailed(String)
    case noPhotoData
}

private final class CaptureSessionBox: @unchecked Sendable {
    nonisolated(unsafe) let session: AVCaptureSession
    nonisolated init() {
        session = AVCaptureSession()
    }
}

actor CameraSession {
    private let box = CaptureSessionBox()
    private var didConfigure = false
    private var hasInputInternal = false

    private var activeDevice: AVCaptureDevice?
    private var activeInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var inFlightDelegates: [UUID: PhotoCaptureDelegate] = [:]

    private(set) var lensPosition: CameraLensPosition = .back
    private(set) var flashMode: CameraFlashMode = .off

    nonisolated var captureSession: AVCaptureSession {
        box.session
    }

    var hasInput: Bool {
        hasInputInternal
    }

    var isRunning: Bool {
        box.session.isRunning
    }

    init() {}

    func authorizationState() -> CameraAuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined: return .notDetermined
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .denied
        }
    }

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

        guard hasInputInternal else { return }

        guard !box.session.isRunning else { return }
        box.session.startRunning()
    }

    func stop() {
        guard box.session.isRunning else { return }
        box.session.stopRunning()
    }

    var minZoomFactor: Double {
        guard let device = activeDevice else { return 1.0 }
        return Double(device.minAvailableVideoZoomFactor)
    }

    var maxZoomFactor: Double {
        guard let device = activeDevice else { return 1.0 }
        return Double(device.maxAvailableVideoZoomFactor)
    }

    var currentZoomFactor: Double {
        guard let device = activeDevice else { return 1.0 }
        return Double(device.videoZoomFactor)
    }

    var ultraWideSwitchOverFactor: Double? {
        guard let device = activeDevice else { return nil }
        return device.virtualDeviceSwitchOverVideoZoomFactors.first.map { Double(truncating: $0) }
    }

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

    func isPresetSupported(_ preset: ZoomPreset) -> Bool {
        guard let device = activeDevice else { return false }
        let target = preset.factor
        if target < 1.0 {
            guard let switchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first else {
                return false
            }
            _ = switchOver
            return Double(device.minAvailableVideoZoomFactor) <= target + 0.0001
        }
        return target <= Double(device.maxAvailableVideoZoomFactor)
    }

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

    func setFlashMode(_ mode: CameraFlashMode) {
        flashMode = mode
        applyTorchState()
    }

    func setLowLightBoost(enabled: Bool) {
        guard let device = activeDevice else { return }
        guard device.isLowLightBoostSupported else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.automaticallyEnablesLowLightBoostWhenAvailable = enabled
        } catch {
            return
        }
    }

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

    var exposureBiasRange: ClosedRange<Float>? {
        guard let device = activeDevice else { return nil }
        return device.minExposureTargetBias ... device.maxExposureTargetBias
    }

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

    private func configureInitialInput() {
        let session = box.session
        session.beginConfiguration()
        defer { session.commitConfiguration() }

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

        guard hasInputInternal else { return }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            photoOutput = output
        }
    }
}

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
