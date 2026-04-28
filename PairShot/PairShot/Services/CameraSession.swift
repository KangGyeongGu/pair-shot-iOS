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

private final class CaptureSessionBox: @unchecked Sendable {
    nonisolated(unsafe) let session: AVCaptureSession
    nonisolated init() {
        session = AVCaptureSession()
    }
}

private final class InterruptionObserverBox: @unchecked Sendable {
    nonisolated(unsafe) var observers: [NSObjectProtocol] = []
    nonisolated init() {}

    nonisolated func cleanup() {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }
}

actor CameraSession {
    private let box = CaptureSessionBox()
    private let observerBox = InterruptionObserverBox()
    private let sessionQueue = DispatchQueue(label: "com.pairshot.camera.session", qos: .userInitiated)
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

    init() {
        registerInterruptionObservers()
    }

    deinit {
        observerBox.cleanup()
    }

    private nonisolated func registerInterruptionObservers() {
        let session = box.session
        let observerBox = observerBox
        let center = NotificationCenter.default
        let interrupted = center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: nil
        ) { notification in
            if let reasonValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
               let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue)
            {
                AppLogger.camera.info("Capture session interrupted: reason \(reason.rawValue, privacy: .public)")
            } else {
                AppLogger.camera.info("Capture session interrupted: reason unknown")
            }
        }
        let resumed = center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.resumeAfterInterruption() }
        }
        let runtimeError = center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            let description = (notification.userInfo?[AVCaptureSessionErrorKey] as? Error)?
                .localizedDescription ?? "unknown"
            AppLogger.camera.error("Capture session runtime error: \(description, privacy: .public)")
            Task { await self.resumeAfterRuntimeError() }
        }
        observerBox.observers = [interrupted, resumed, runtimeError]
    }

    private func resumeAfterInterruption() async {
        guard didConfigure, hasInputInternal else { return }
        let session = box.session
        await runOnSessionQueueVoid {
            guard !session.isRunning else { return }
            session.startRunning()
        }
        AppLogger.camera.info("Capture session resumed after interruption")
    }

    private func resumeAfterRuntimeError() async {
        guard didConfigure, hasInputInternal else { return }
        let session = box.session
        await runOnSessionQueueVoid {
            if session.isRunning {
                session.stopRunning()
            }
            session.startRunning()
        }
        AppLogger.camera.info("Capture session resumed after runtime error")
    }

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
        AppLogger.camera.debug("Camera session start requested")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                break

            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                guard granted else {
                    AppLogger.camera.debug("Camera permission denied at prompt")
                    return
                }

            case .denied, .restricted:
                AppLogger.camera.debug("Camera permission unavailable (denied/restricted)")
                return

            @unknown default:
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

    func zoomSnapshot() async -> CameraZoomSnapshot {
        guard let device = activeDevice else { return CameraZoomSnapshot.empty }
        return await runOnSessionQueue {
            let presets = ZoomPresetBuilder.build(for: device)
            let firstSwitch = device.virtualDeviceSwitchOverVideoZoomFactors
                .first.map { Double(truncating: $0) } ?? 1.0
            let recommendedMax = if #available(iOS 18.0, *),
                                    let range = device.activeFormat.systemRecommendedVideoZoomRange
            {
                Double(range.upperBound)
            } else {
                Double(device.maxAvailableVideoZoomFactor)
            }
            let multiplier: Double
            if #available(iOS 18.0, *) {
                let raw = Double(device.displayVideoZoomFactorMultiplier)
                multiplier = raw > 0 ? raw : 1.0
            } else {
                multiplier = firstSwitch > 0 ? 1.0 / firstSwitch : 1.0
            }
            return CameraZoomSnapshot(
                minFactor: Double(device.minAvailableVideoZoomFactor),
                maxFactor: recommendedMax,
                currentFactor: Double(device.videoZoomFactor),
                firstSwitchOver: firstSwitch,
                displayMultiplier: multiplier,
                presets: presets,
                exposureBiasRange: device.minExposureTargetBias ... device.maxExposureTargetBias
            )
        }
    }

    var minZoomFactor: Double {
        get async {
            guard let device = activeDevice else { return 1.0 }
            return await runOnSessionQueue { Double(device.minAvailableVideoZoomFactor) }
        }
    }

    var maxZoomFactor: Double {
        get async {
            guard let device = activeDevice else { return 1.0 }
            return await runOnSessionQueue {
                if #available(iOS 18.0, *), let range = device.activeFormat.systemRecommendedVideoZoomRange {
                    return Double(range.upperBound)
                }
                return Double(device.maxAvailableVideoZoomFactor)
            }
        }
    }

    var currentZoomFactor: Double {
        get async {
            guard let device = activeDevice else { return 1.0 }
            return await runOnSessionQueue { Double(device.videoZoomFactor) }
        }
    }

    var ultraWideSwitchOverFactor: Double? {
        get async {
            guard let device = activeDevice else { return nil }
            return await runOnSessionQueue {
                device.virtualDeviceSwitchOverVideoZoomFactors
                    .first.map { Double(truncating: $0) }
            }
        }
    }

    var firstSwitchOver: Double {
        get async {
            guard let device = activeDevice else { return 1.0 }
            return await runOnSessionQueue {
                device.virtualDeviceSwitchOverVideoZoomFactors
                    .first.map { Double(truncating: $0) } ?? 1.0
            }
        }
    }

    var availablePresets: [ZoomPresetSpec] {
        get async {
            guard let device = activeDevice else { return [] }
            return await runOnSessionQueue { ZoomPresetBuilder.build(for: device) }
        }
    }

    func ramp(toZoomFactor factor: Double, rate: Float = 4.0) async {
        guard let device = activeDevice else { return }
        await runOnSessionQueueVoid {
            let minF = Double(device.minAvailableVideoZoomFactor)
            let maxF = Double(device.maxAvailableVideoZoomFactor)
            let clamped = max(minF, min(factor, maxF))
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.ramp(toVideoZoomFactor: CGFloat(clamped), withRate: rate)
            } catch {
                AppLogger.camera.error("Camera zoom ramp failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    func setZoomFactor(_ factor: Double) async {
        guard let device = activeDevice else { return }
        await runOnSessionQueueVoid {
            let minF = Double(device.minAvailableVideoZoomFactor)
            let maxF = Double(device.maxAvailableVideoZoomFactor)
            let clamped = max(minF, min(factor, maxF))
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isRampingVideoZoom { device.cancelVideoZoomRamp() }
                device.videoZoomFactor = CGFloat(clamped)
            } catch {
                AppLogger.camera.error("Camera zoom set failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    func switchLens(to position: CameraLensPosition) async {
        guard didConfigure else { return }

        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        let session = box.session
        let priorInput = activeInput
        let currentPhotoOutput = photoOutput

        let result = await runOnSessionQueue { () -> SwitchLensResult? in
            guard let device = Self.preferredDevice(for: avPosition) else { return nil }

            session.beginConfiguration()
            defer { session.commitConfiguration() }

            if let priorInput {
                session.removeInput(priorInput)
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else { return nil }
                session.addInput(input)
                Self.applyDefaultZoom(to: device)
                if let currentPhotoOutput {
                    Self.applyMaxPhotoDimensions(to: currentPhotoOutput, device: device)
                }
                return SwitchLensResult(device: device, input: input)
            } catch {
                AppLogger.camera.error("Camera lens switch failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        guard let result else { return }
        activeDevice = result.device
        activeInput = result.input
        lensPosition = position
        hasInputInternal = true
        AppLogger.camera.debug("Camera lens switched to \(position.rawValue, privacy: .public)")
    }

    private static func preferredDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
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

    private nonisolated static func applyDefaultZoom(to device: AVCaptureDevice) {
        guard let firstSwitch = device.virtualDeviceSwitchOverVideoZoomFactors.first else { return }
        let target = CGFloat(truncating: firstSwitch)
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = max(target, device.minAvailableVideoZoomFactor)
        } catch {
            AppLogger.camera.error("Default zoom set failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated static func applyMaxPhotoDimensions(
        to output: AVCapturePhotoOutput,
        device: AVCaptureDevice
    ) {
        let supported = device.activeFormat.supportedMaxPhotoDimensions
        guard let largest = supported.last else { return }
        output.maxPhotoDimensions = largest
    }

    func setFlashMode(_ mode: CameraFlashMode) async {
        flashMode = mode
        await applyTorchState()
    }

    func setLowLightBoost(enabled: Bool) async {
        guard let device = activeDevice else { return }
        await runOnSessionQueueVoid {
            guard device.isLowLightBoostSupported else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.automaticallyEnablesLowLightBoostWhenAvailable = enabled
            } catch {
                AppLogger.camera
                    .error("Camera low-light boost configure failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    func cycleFlashMode() async -> CameraFlashMode {
        let next = flashMode.next
        await setFlashMode(next)
        return next
    }

    private func applyTorchState() async {
        guard let device = activeDevice else { return }
        let mode = flashMode
        await runOnSessionQueueVoid {
            guard device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                switch mode {
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
                AppLogger.camera.error("Camera torch configure failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    func focus(at point: CGPoint) async {
        guard let device = activeDevice else { return }
        await runOnSessionQueueVoid {
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
                AppLogger.camera.error("Camera focus configure failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
    }

    var exposureBiasRange: ClosedRange<Float>? {
        get async {
            guard let device = activeDevice else { return nil }
            return await runOnSessionQueue {
                device.minExposureTargetBias ... device.maxExposureTargetBias
            }
        }
    }

    func setExposureBias(_ bias: Float) async {
        guard let device = activeDevice else { return }
        let queue = sessionQueue
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                do {
                    try device.lockForConfiguration()
                    let clamped = max(device.minExposureTargetBias, min(bias, device.maxExposureTargetBias))
                    device.setExposureTargetBias(clamped) { _ in
                        device.unlockForConfiguration()
                        cont.resume()
                    }
                } catch {
                    AppLogger.camera
                        .error("Camera exposure bias set failed: \(error.localizedDescription, privacy: .public)")
                    cont.resume()
                }
            }
        }
    }

    func capturePhoto() async throws -> CapturedPhoto {
        guard let photoOutput, let device = activeDevice else {
            AppLogger.camera.error("Camera capturePhoto failed: not configured")
            throw CameraSessionError.notConfigured
        }

        let settings = AVCapturePhotoSettings()
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        if device.hasFlash {
            switch flashMode {
                case .auto: settings.flashMode = .auto
                case .on: settings.flashMode = .on
                case .off, .torch: settings.flashMode = .off
            }
        }

        let zoom = Double(device.videoZoomFactor)
        let lens = lensIdentifier(for: device)
        let queue = sessionQueue

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
                        AppLogger.camera
                            .error("Camera capturePhoto failed: \(String(describing: err), privacy: .public)")
                        cont.resume(throwing: err)
                }
            }
            inFlightDelegates[id] = delegate
            queue.async {
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
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

    private func configureInitialInput() async {
        let session = box.session
        let resultBox = await runOnSessionQueue {
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
            var resolvedOutput: AVCapturePhotoOutput?
            if session.canAddOutput(output) {
                session.addOutput(output)
                Self.applyMaxPhotoDimensions(to: output, device: device)
                resolvedOutput = output
            }

            return InitialInputResult(
                device: device,
                input: input,
                photoOutput: resolvedOutput,
                hasInput: true
            )
        }
        activeDevice = resultBox.device
        activeInput = resultBox.input
        photoOutput = resultBox.photoOutput
        hasInputInternal = resultBox.hasInput
        if resultBox.hasInput {
            lensPosition = .back
        }
    }

    private func runOnSessionQueue<T: Sendable>(
        _ body: @escaping @Sendable () -> T
    ) async -> T {
        let queue = sessionQueue
        return await withCheckedContinuation { (cont: CheckedContinuation<T, Never>) in
            queue.async {
                cont.resume(returning: body())
            }
        }
    }

    private func runOnSessionQueueVoid(
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

private final class SwitchLensResult: @unchecked Sendable {
    nonisolated(unsafe) let device: AVCaptureDevice
    nonisolated(unsafe) let input: AVCaptureDeviceInput

    nonisolated init(device: AVCaptureDevice, input: AVCaptureDeviceInput) {
        self.device = device
        self.input = input
    }
}

private final nonisolated class InitialInputResult: @unchecked Sendable {
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
