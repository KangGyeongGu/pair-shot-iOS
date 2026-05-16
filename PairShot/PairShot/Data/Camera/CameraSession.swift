@preconcurrency import AVFoundation
import Foundation
import UIKit
import UniformTypeIdentifiers

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
    let data: Data
    let utType: UTType
    let zoomFactor: Double
    let lensIdentifier: String
    let isDeferredProxy: Bool
}

nonisolated enum CameraSessionError: Error {
    case notConfigured
    case captureFailed(String)
    case noPhotoData
}

nonisolated struct CameraZoomSnapshot {
    static let empty = Self(
        minFactor: 1,
        maxFactor: 1,
        currentFactor: 1,
        firstSwitchOver: 1,
        displayMultiplier: 1,
        presets: [],
        exposureBiasRange: nil,
    )

    let minFactor: Double
    let maxFactor: Double
    let currentFactor: Double
    let firstSwitchOver: Double
    let displayMultiplier: Double
    let presets: [ZoomPresetSpec]
    let exposureBiasRange: ClosedRange<Float>?
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
        let firstSwitch =
            device.virtualDeviceSwitchOverVideoZoomFactors
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
    var flashMode: CameraFlashMode = .off
    var currentAspectRatio: AspectRatio = .default
    weak var managedPreviewLayer: AVCaptureVideoPreviewLayer?
    var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    var rotationObservers: [NSKeyValueObservation] = []
    var readinessCoordinator: AVCapturePhotoOutputReadinessCoordinator?
    var readinessAdapter: CameraReadinessAdapter?
    var captureReadiness: AVCapturePhotoOutput.CaptureReadiness = .sessionNotRunning

    var captureSession: AVCaptureSession {
        box.session
    }

    init(
        permissionResolver: @escaping @Sendable () async -> CameraAuthorizationState =
            CameraSessionPermissionResolver.systemDefault,
    ) {
        self.permissionResolver = permissionResolver
        registerInterruptionObservers()
    }

    func start() async {
        let state = await permissionResolver()
        switch state {
            case .authorized:
                break

            case .notDetermined, .denied, .restricted:
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
            return
        }

        let session = box.session
        await runOnSessionQueueVoid {
            guard !session.isRunning else { return }
            session.startRunning()
        }
        await MainActor.run { [weak self] in
            self?.setupRotationCoordinator()
            self?.setupReadinessCoordinator()
        }
    }

    func stop() async {
        let session = box.session
        await runOnSessionQueueVoid {
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configureInitialInput() async {
        let session = box.session
        await runOnSessionQueueVoid { [weak self] in
            guard let self else { return }

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
                return
            }

            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else {
                session.removeInput(input)
                return
            }
            session.addOutput(output)
            output.maxPhotoQualityPrioritization = .quality
            ResponsiveCaptureOptions.apply(to: output)

            activeDevice = device
            activeInput = input
            photoOutput = output
            hasInputInternal = true
            didConfigure = true
        }
    }

    @MainActor
    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        managedPreviewLayer = layer
        setupRotationCoordinator()
    }

    @MainActor
    func setupReadinessCoordinator() {
        let queue = sessionQueue
        queue.async { [weak self] in
            guard let output = self?.photoOutput else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let coordinator = AVCapturePhotoOutputReadinessCoordinator(photoOutput: output)
                let adapter = CameraReadinessAdapter { [weak self] readiness in
                    self?.captureReadiness = readiness
                }
                coordinator.delegate = adapter
                readinessCoordinator = coordinator
                readinessAdapter = adapter
            }
        }
    }

    @MainActor
    func setupRotationCoordinator() {
        rotationObservers.removeAll()
        rotationCoordinator = nil
        guard let device = activeDevice, let previewLayer = managedPreviewLayer else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        previewLayer.connection?.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
        applyCaptureRotationAngle(coordinator.videoRotationAngleForHorizonLevelCapture)
        let prevObserver = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.new],
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in
                self?.managedPreviewLayer?.connection?.videoRotationAngle = angle
            }
        }
        let captureObserver = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.new],
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in
                self?.applyCaptureRotationAngle(angle)
            }
        }
        rotationObservers = [prevObserver, captureObserver]
        rotationCoordinator = coordinator
    }

    @MainActor
    private func applyCaptureRotationAngle(_ angle: CGFloat) {
        let queue = sessionQueue
        let output = photoOutput
        queue.async {
            guard let connection = output?.connection(with: .video) else { return }
            guard connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }

    func runOnSessionQueue<T: Sendable>(
        _ body: @escaping @Sendable () -> T,
    ) async -> T {
        let queue = sessionQueue
        return await withCheckedContinuation { (cont: CheckedContinuation<T, Never>) in
            queue.async {
                cont.resume(returning: body())
            }
        }
    }

    func runOnSessionQueueVoid(
        _ body: @escaping @Sendable () -> Void,
    ) async {
        let queue = sessionQueue
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                body()
                cont.resume()
            }
        }
    }

    deinit {
        observerBox.cleanup()
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

nonisolated enum ResponsiveCaptureOptions {
    static func apply(to output: AVCapturePhotoOutput) {
        if output.isZeroShutterLagSupported {
            output.isZeroShutterLagEnabled = true
        }
        if output.isResponsiveCaptureSupported {
            output.isResponsiveCaptureEnabled = true
        }
        if output.isFastCapturePrioritizationSupported {
            output.isFastCapturePrioritizationEnabled = true
        }
        if output.isAutoDeferredPhotoDeliverySupported {
            output.isAutoDeferredPhotoDeliveryEnabled = true
        }
    }
}

@MainActor
final class CameraReadinessAdapter: NSObject, AVCapturePhotoOutputReadinessCoordinatorDelegate {
    let onChange: @MainActor (AVCapturePhotoOutput.CaptureReadiness) -> Void

    init(onChange: @escaping @MainActor (AVCapturePhotoOutput.CaptureReadiness) -> Void) {
        self.onChange = onChange
    }

    nonisolated func readinessCoordinator(
        _: AVCapturePhotoOutputReadinessCoordinator,
        captureReadinessDidChange captureReadiness: AVCapturePhotoOutput.CaptureReadiness,
    ) {
        Task { @MainActor in self.onChange(captureReadiness) }
    }
}
