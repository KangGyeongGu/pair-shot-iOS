@preconcurrency import AVFoundation
import Foundation
import OSLog
import UIKit

nonisolated enum CameraAuthorizationState {
    case notDetermined
    case authorized
    case denied
    case restricted
}

nonisolated enum CameraLensPosition: String, CaseIterable {
    case back
    case front
}

nonisolated enum CameraFlashMode: String, CaseIterable {
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

nonisolated struct CapturedPhoto {
    let jpegData: Data
    let zoomFactor: Double
    let lensIdentifier: String
    let capturedAt: Date
}

nonisolated enum CameraSessionError: Error {
    case notConfigured
    case deviceUnavailable
    case captureFailed(String)
    case noPhotoData
}

struct CameraZoomSnapshot {
    let minFactor: Double
    let maxFactor: Double
    let currentFactor: Double
    let firstSwitchOver: Double
    let displayMultiplier: Double
    let presets: [ZoomPresetSpec]
    let exposureBiasRange: ClosedRange<Float>?

    nonisolated static let empty = Self(
        minFactor: 1,
        maxFactor: 1,
        currentFactor: 1,
        firstSwitchOver: 1,
        displayMultiplier: 1,
        presets: [],
        exposureBiasRange: nil
    )
}

nonisolated enum CameraZoomCapabilities {
    static func recommendedMaxFactor(for device: AVCaptureDevice) -> Double {
        if #available(iOS 18.0, *),
           let range = device.activeFormat.systemRecommendedVideoZoomRange
        {
            return Double(range.upperBound)
        }
        return Double(device.maxAvailableVideoZoomFactor)
    }

    static func displayMultiplier(for device: AVCaptureDevice) -> Double {
        if #available(iOS 18.0, *) {
            let raw = Double(device.displayVideoZoomFactorMultiplier)
            return raw > 0 ? raw : 1.0
        }
        let firstSwitch = device.virtualDeviceSwitchOverVideoZoomFactors
            .first.map { Double(truncating: $0) } ?? 1.0
        return firstSwitch > 0 ? 1.0 / firstSwitch : 1.0
    }
}

final class CaptureSessionBox: @unchecked Sendable {
    nonisolated(unsafe) let session: AVCaptureSession
    nonisolated init() {
        session = AVCaptureSession()
    }
}

actor CameraSession {
    let box = CaptureSessionBox()
    let observerBox = InterruptionObserverBox()
    let sessionQueue = DispatchQueue(label: "com.pairshot.camera.session", qos: .userInitiated)
    private let permissionResolver: @Sendable () async -> CameraAuthorizationState
    var didConfigure = false
    var hasInputInternal = false

    var activeDevice: AVCaptureDevice?
    var activeInput: AVCaptureDeviceInput?
    var photoOutput: AVCapturePhotoOutput?
    var inFlightDelegates: [UUID: PhotoCaptureDelegate] = [:]

    private(set) var lensPosition: CameraLensPosition = .back
    var flashMode: CameraFlashMode = .off

    nonisolated var captureSession: AVCaptureSession {
        box.session
    }

    var hasInput: Bool {
        hasInputInternal
    }

    var isRunning: Bool {
        box.session.isRunning
    }

    init(
        permissionResolver: @escaping @Sendable () async -> CameraAuthorizationState =
            CameraSessionPermissionResolver.systemDefault
    ) {
        self.permissionResolver = permissionResolver
        registerInterruptionObservers()
    }

    deinit {
        observerBox.cleanup()
    }

    func authorizationState() async -> CameraAuthorizationState {
        await permissionResolver()
    }

    func start() async {
        AppLogger.camera.debug("Camera session start requested")
        let state = await permissionResolver()
        switch state {
            case .authorized:
                break

            case .notDetermined, .denied, .restricted:
                AppLogger.camera.debug(
                    "Camera permission unavailable state=\(String(describing: state), privacy: .public)"
                )
                return
        }

        if !didConfigure {
            await configureInitialInput()
            didConfigure = true
        }

        guard hasInputInternal else {
            AppLogger.camera.error("Camera session start aborted: no input device")
            return
        }

        let session = box.session
        await runOnSessionQueueVoid {
            guard !session.isRunning else { return }
            session.startRunning()
        }
        AppLogger.camera.debug("Camera session started")
    }

    func stop() async {
        let session = box.session
        await runOnSessionQueueVoid {
            guard session.isRunning else { return }
            session.stopRunning()
        }
        AppLogger.camera.debug("Camera session stopped")
    }

    func updateLensPosition(_ position: CameraLensPosition) {
        lensPosition = position
    }

    private func configureInitialInput() async {
        let session = box.session
        var resultBox = InitialInputResult(device: nil, input: nil, photoOutput: nil, hasInput: false)
        var attempt = 0
        while attempt < 2 {
            resultBox = await runOnSessionQueue {
                session.beginConfiguration()
                defer { session.commitConfiguration() }

                if session.canSetSessionPreset(.photo) {
                    session.sessionPreset = .photo
                }

                let candidates: [AVCaptureDevice.DeviceType] = [
                    .builtInTripleCamera,
                    .builtInDualWideCamera,
                    .builtInDualCamera,
                    .builtInWideAngleCamera,
                ]
                var resolvedDevice: AVCaptureDevice?
                var resolvedInput: AVCaptureDeviceInput?
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
                    Self.applyDefaultZoom(to: device)
                    resolvedDevice = device
                    resolvedInput = input
                    break
                }

                guard let device = resolvedDevice, let input = resolvedInput else {
                    return InitialInputResult(device: nil, input: nil, photoOutput: nil, hasInput: false)
                }

                let output = AVCapturePhotoOutput()
                guard session.canAddOutput(output) else {
                    AppLogger.camera.error("Camera session canAddOutput=false; rolling back input")
                    session.removeInput(input)
                    return InitialInputResult(device: nil, input: nil, photoOutput: nil, hasInput: false)
                }
                session.addOutput(output)
                Self.applyMaxPhotoDimensions(to: output, device: device)

                return InitialInputResult(
                    device: device,
                    input: input,
                    photoOutput: output,
                    hasInput: true
                )
            }
            if resultBox.hasInput, resultBox.photoOutput != nil { break }
            attempt += 1
            if attempt < 2 {
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
        activeDevice = resultBox.device
        activeInput = resultBox.input
        photoOutput = resultBox.photoOutput
        hasInputInternal = resultBox.hasInput
        if resultBox.hasInput {
            lensPosition = .back
        }
    }

    func runOnSessionQueue<T: Sendable>(
        _ body: @escaping @Sendable () -> T
    ) async -> T {
        let queue = sessionQueue
        return await withCheckedContinuation { (cont: CheckedContinuation<T, Never>) in
            queue.async {
                cont.resume(returning: body())
            }
        }
    }

    func runOnSessionQueueVoid(
        _ body: @escaping @Sendable () -> Void
    ) async {
        let queue = sessionQueue
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                body()
                cont.resume()
            }
        }
    }
}

enum CameraSessionPermissionResolver {
    @Sendable
    static func systemDefault() async -> CameraAuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                return .authorized

            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                return granted ? .authorized : .denied

            case .denied:
                return .denied

            case .restricted:
                return .restricted

            @unknown default:
                return .denied
        }
    }
}

nonisolated final class InitialInputResult: @unchecked Sendable {
    let device: AVCaptureDevice?
    let input: AVCaptureDeviceInput?
    let photoOutput: AVCapturePhotoOutput?
    let hasInput: Bool

    init(
        device: AVCaptureDevice?,
        input: AVCaptureDeviceInput?,
        photoOutput: AVCapturePhotoOutput?,
        hasInput: Bool
    ) {
        self.device = device
        self.input = input
        self.photoOutput = photoOutput
        self.hasInput = hasInput
    }
}

struct ZoomPresetSpec: Identifiable, Hashable {
    let id: String
    let factor: Double
    let label: String
}
