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

nonisolated struct CameraZoomSnapshot {
    let minFactor: Double
    let maxFactor: Double
    let currentFactor: Double
    let firstSwitchOver: Double
    let displayMultiplier: Double
    let presets: [ZoomPresetSpec]
    let exposureBiasRange: ClosedRange<Float>?

    static let empty = Self(
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

final nonisolated class CaptureSessionBox: @unchecked Sendable {
    let session: AVCaptureSession
    init() {
        session = AVCaptureSession()
    }
}

final nonisolated class CameraSession: @unchecked Sendable {
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
    var lensPositionStorage: CameraLensPosition = .back
    var flashMode: CameraFlashMode = .off
    weak var managedPreviewLayer: AVCaptureVideoPreviewLayer?
    var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    var rotationObservers: [NSKeyValueObservation] = []

    var captureSession: AVCaptureSession {
        box.session
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

        let alreadyConfigured = await runOnSessionQueue { [weak self] in
            self?.didConfigure ?? false
        }
        if !alreadyConfigured {
            await configureInitialInput()
        }

        let canStart = await runOnSessionQueue { [weak self] in
            self?.hasInputInternal ?? false
        }
        guard canStart else {
            AppLogger.camera.error("Camera session start aborted: no input device")
            return
        }

        let session = box.session
        await runOnSessionQueueVoid {
            guard !session.isRunning else { return }
            session.startRunning()
        }
        AppLogger.camera.debug("Camera session started")
        await MainActor.run { [weak self] in
            self?.setupRotationCoordinator()
        }
    }

    func stop() async {
        let session = box.session
        await runOnSessionQueueVoid {
            guard session.isRunning else { return }
            session.stopRunning()
        }
        AppLogger.camera.debug("Camera session stopped")
    }

    func lensPosition() async -> CameraLensPosition {
        await runOnSessionQueue { [weak self] in
            self?.lensPositionStorage ?? .back
        }
    }

    private func configureInitialInput() async {
        let session = box.session
        var attempt = 0
        while attempt < 2 {
            let success = await runOnSessionQueue { [weak self] () -> Bool in
                guard let self else { return false }

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
                    return false
                }

                let output = AVCapturePhotoOutput()
                guard session.canAddOutput(output) else {
                    AppLogger.camera.error("Camera session canAddOutput=false; rolling back input")
                    session.removeInput(input)
                    return false
                }
                session.addOutput(output)
                Self.applyMaxPhotoDimensions(to: output, device: device)

                activeDevice = device
                activeInput = input
                photoOutput = output
                hasInputInternal = true
                lensPositionStorage = .back
                didConfigure = true
                return true
            }
            if success { break }
            attempt += 1
            if attempt < 2 {
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    @MainActor
    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        managedPreviewLayer = layer
        setupRotationCoordinator()
    }

    @MainActor
    func setupRotationCoordinator() {
        rotationObservers.removeAll()
        rotationCoordinator = nil
        guard let device = activeDevice, let previewLayer = managedPreviewLayer else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        previewLayer.connection?.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
        let prevObserver = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.new]
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in
                self?.managedPreviewLayer?.connection?.videoRotationAngle = angle
            }
        }
        rotationObservers = [prevObserver]
        rotationCoordinator = coordinator
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

nonisolated enum CameraSessionPermissionResolver {
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

nonisolated struct ZoomPresetSpec: Identifiable, Hashable {
    let id: String
    let factor: Double
    let label: String
}
