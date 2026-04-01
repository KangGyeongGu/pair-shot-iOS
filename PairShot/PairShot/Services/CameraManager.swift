@preconcurrency import AVFoundation
import CoreImage
import Observation
import UIKit

@Observable
@MainActor
final class CameraManager: NSObject, CameraServiceProtocol {
    private(set) var isSessionRunning: Bool = false
    private(set) var isCameraAuthorized: Bool = false
    private(set) var capturedPhoto: UIImage?
    var saveResult: SaveResult?

    struct SaveResult: Equatable {
        let filePath: String
        let thumbnailPath: String
        let isBefore: Bool
        let pairId: UUID
    }

    // nonisolated(unsafe): sessionQueue에서만 접근하므로 안전 — Swift 6 Sendable 경고 억제
    @ObservationIgnored
    private nonisolated(unsafe) let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.pairshot.camera.sessionQueue", qos: .userInitiated)

    @ObservationIgnored
    private nonisolated(unsafe) var videoDeviceInput: AVCaptureDeviceInput?
    @ObservationIgnored
    private nonisolated(unsafe) let photoOutput = AVCapturePhotoOutput()
    @ObservationIgnored
    private nonisolated(unsafe) var currentCameraPosition: AVCaptureDevice.Position = .back

    private var pendingProjectId: UUID?
    private var pendingPairId: UUID?
    private var pendingIsBefore: Bool = true

    let previewLayer: AVCaptureVideoPreviewLayer

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
        observeAppLifecycle()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func requestAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                await MainActor.run { isCameraAuthorized = true }
                return true
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await MainActor.run { isCameraAuthorized = granted }
                return granted
            default:
                await MainActor.run { isCameraAuthorized = false }
                return false
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if session.inputs.isEmpty {
                configureSession()
            }
            if !session.isRunning {
                session.startRunning()
            }
            let running = session.isRunning
            Task { @MainActor in
                self.isSessionRunning = running
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if session.isRunning {
                session.stopRunning()
            }
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }

    func capturePhoto(projectId: UUID, pairId: UUID, isBefore: Bool = true) {
        pendingProjectId = projectId
        pendingPairId = pairId
        pendingIsBefore = isBefore

        let settings = makePhotoSettings()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    struct ZoomInfo {
        let minFactor: CGFloat
        let maxFactor: CGFloat
        let recommendedMaxFactor: CGFloat
        let displayMultiplier: CGFloat
        let allFixedFactors: [CGFloat]
        let focalLengthMap: [CGFloat: Int] // zoomFactor → 35mm 환산 초점거리 (mm)
        let defaultFactor: CGFloat
    }

    func getZoomInfo() -> ZoomInfo {
        guard let device = videoDeviceInput?.device else {
            return ZoomInfo(
                minFactor: 1.0,
                maxFactor: 1.0,
                recommendedMaxFactor: 1.0,
                displayMultiplier: 1.0,
                allFixedFactors: [1.0],
                focalLengthMap: [:],
                defaultFactor: 1.0
            )
        }
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        let secondaryNative = device.activeFormat.secondaryNativeResolutionZoomFactors
        let multiplier = device.displayVideoZoomFactorMultiplier
        let defaultZoom: CGFloat = multiplier > 0 ? (1.0 / multiplier) : (switchOvers.first ?? 1.0)

        let allFixed = buildAllFixedFactors(
            device: device,
            switchOvers: switchOvers,
            secondaryNative: secondaryNative,
            defaultZoom: defaultZoom
        )
        let focalMap = buildFocalLengthMap(
            device: device,
            switchOvers: switchOvers,
            secondaryNative: secondaryNative,
            allFixed: allFixed,
            defaultZoom: defaultZoom
        )

        let recommendedMax: CGFloat = if let range = device.activeFormat.systemRecommendedVideoZoomRange {
            range.upperBound
        } else {
            device.maxAvailableVideoZoomFactor
        }

        return ZoomInfo(
            minFactor: device.minAvailableVideoZoomFactor,
            maxFactor: device.maxAvailableVideoZoomFactor,
            recommendedMaxFactor: recommendedMax,
            displayMultiplier: multiplier,
            allFixedFactors: allFixed.sorted(),
            focalLengthMap: focalMap,
            defaultFactor: defaultZoom
        )
    }

    private func buildAllFixedFactors(
        device: AVCaptureDevice,
        switchOvers: [CGFloat],
        secondaryNative: [CGFloat],
        defaultZoom: CGFloat
    ) -> Set<CGFloat> {
        var allFixed = Set<CGFloat>([device.minAvailableVideoZoomFactor])
        switchOvers.forEach { allFixed.insert($0) }
        secondaryNative.forEach { allFixed.insert($0) }

        // 28mm/35mm 화각 포인트 추가 (와이드 렌즈가 48MP인 Pro 모델에서 네이티브 크롭)
        let wideDevice = device.constituentDevices.first { $0.deviceType == .builtInWideAngleCamera }
        if let wide = wideDevice {
            let wideFocal = CGFloat(wide.nominalFocalLengthIn35mmFilm)
            let wideZoom = switchOvers.first ?? defaultZoom
            if wideFocal > 0 {
                for focal in [28, 35] as [CGFloat] {
                    let factor = wideZoom * (focal / wideFocal)
                    if factor > wideZoom, factor <= (secondaryNative.first ?? factor) {
                        allFixed.insert(factor)
                    }
                }
            }
        }
        return allFixed
    }

    private func buildFocalLengthMap(
        device: AVCaptureDevice,
        switchOvers: [CGFloat],
        secondaryNative: [CGFloat],
        allFixed: Set<CGFloat>,
        defaultZoom: CGFloat
    ) -> [CGFloat: Int] {
        var focalMap: [CGFloat: Int] = [:]
        let constituents = device.constituentDevices
        var zoomForConstituent: [CGFloat] = [device.minAvailableVideoZoomFactor]
        zoomForConstituent.append(contentsOf: switchOvers)
        for (i, constituent) in constituents.enumerated() {
            let focal = constituent.nominalFocalLengthIn35mmFilm
            if focal > 0, i < zoomForConstituent.count {
                focalMap[zoomForConstituent[i]] = Int(focal)
            }
        }

        let wideDevice = device.constituentDevices.first { $0.deviceType == .builtInWideAngleCamera }
        if let wide = wideDevice {
            let wideFocal = CGFloat(wide.nominalFocalLengthIn35mmFilm)
            let wideZoom = switchOvers.first ?? defaultZoom
            if wideFocal > 0 {
                for focal in [28, 35] as [CGFloat] {
                    let factor = wideZoom * (focal / wideFocal)
                    if allFixed.contains(factor) || allFixed.contains(where: { abs($0 - factor) < 0.01 }) {
                        focalMap[factor] = Int(focal)
                    }
                }
                if let secZoom = secondaryNative.first {
                    let focal = wideFocal * (secZoom / wideZoom)
                    focalMap[secZoom] = Int(focal)
                }
            }
        }
        return focalMap
    }

    private nonisolated func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let device = Self.captureDevice(for: .back) else { return }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
                currentCameraPosition = .back
            }
        } catch {
            return
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // 트리플/듀얼 카메라의 기본 videoZoomFactor 1.0은 울트라와이드(0.5x) 렌즈 기준.
        // 기본 카메라 앱의 1x(24mm 메인 렌즈)와 일치시키려면 2.0으로 설정.
        do {
            try device.lockForConfiguration()
            if device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera {
                device.videoZoomFactor = 2.0
            }
            device.unlockForConfiguration()
        } catch {}
    }

    private func makePhotoSettings() -> AVCapturePhotoSettings {
        let settings
            // HEIC/HEIF 지원 기기는 HEIC, 미지원 기기는 JPEG fallback
            = if photoOutput.availablePhotoCodecTypes.contains(.hevc)
        {
            AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            AVCapturePhotoSettings()
        }

        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions

        if photoOutput.supportedFlashModes.contains(.auto) {
            settings.flashMode = .auto
        }

        return settings
    }

    private nonisolated static func captureDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // 후면: 트리플/듀얼 카메라 우선 (멀티렌즈 줌 지원), 없으면 와이드 앵글로 폴백
        let deviceTypes: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInTrueDepthCamera, .builtInWideAngleCamera]

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        return discoverySession.devices.first
    }

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private nonisolated func handleWillResignActive() {
        Task { @MainActor in
            self.stopSession()
        }
    }

    @objc private nonisolated func handleDidBecomeActive() {
        Task { @MainActor in
            guard self.isCameraAuthorized else { return }
            self.startSession()
        }
    }
}

extension CameraManager {
    /// 버튼 탭: `ramp(toVideoZoomFactor:withRate:)` 로 부드럽게 전환
    func setZoom(factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let clamped = max(
                    device.minAvailableVideoZoomFactor,
                    min(factor, device.maxAvailableVideoZoomFactor)
                )
                device.ramp(toVideoZoomFactor: clamped, withRate: 8.0)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    /// 드래그 제스처: `videoZoomFactor` 직접 설정 — 호출 스레드에서 즉시 실행 (지연 없음)
    func setZoomDirect(factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            let clamped = max(
                device.minAvailableVideoZoomFactor,
                min(factor, device.maxAvailableVideoZoomFactor)
            )
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {}
    }

    // 터치한 지점에 포커스 + 노출 조정 (화면 좌표 → previewLayer 변환)

    func focusAndExpose(at screenPoint: CGPoint) {
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: screenPoint)
        sessionQueue.async { [weak self] in
            guard let self, let device = videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .autoExpose
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
            } catch {}
        }
    }

    /// 피사체 변경 시 연속 자동 포커스/노출로 복귀
    func resetFocusAndExposure() {
        sessionQueue.async { [weak self] in
            guard let self, let device = videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                    device.exposureMode = .continuousAutoExposure
                }
                device.isSubjectAreaChangeMonitoringEnabled = false
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func setExposureBias(_ bias: Float) {
        sessionQueue.async { [weak self] in
            guard let self, let device = videoDeviceInput?.device else { return }
            let range = Self.recommendedExposureRange(for: device)
            let clamped = max(range.min, min(bias, range.max))
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func getExposureBiasRange() -> (min: Float, max: Float) {
        guard let device = videoDeviceInput?.device else { return (-3, 3) }
        return Self.recommendedExposureRange(for: device)
    }

    private nonisolated static func recommendedExposureRange(for device: AVCaptureDevice) -> (min: Float, max: Float) {
        // iOS 18+: Apple이 기기별로 권장하는 노출 범위
        if let range = device.activeFormat.systemRecommendedExposureBiasRange {
            return (range.lowerBound, range.upperBound)
        }
        // fallback: 하드웨어 범위를 ±3 EV로 제한
        let limit: Float = 3.0
        return (max(device.minExposureTargetBias, -limit), min(device.maxExposureTargetBias, limit))
    }

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let newPosition: AVCaptureDevice.Position = currentCameraPosition == .back ? .front : .back
            guard let newDevice = Self.captureDevice(for: newPosition) else { return }

            session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            if let currentInput = videoDeviceInput {
                session.removeInput(currentInput)
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    videoDeviceInput = newInput
                    currentCameraPosition = newPosition
                }
            } catch {
                // 전환 실패 시 기존 입력 복구
                if let existing = videoDeviceInput,
                   session.canAddInput(existing)
                {
                    session.addInput(existing)
                }
            }
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation()
        else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let projectId = pendingProjectId
            let pairId = pendingPairId
            let isBefore = pendingIsBefore
            pendingProjectId = nil
            pendingPairId = nil
            pendingIsBefore = true

            if let image = UIImage(data: data) {
                capturedPhoto = image
            }

            Task.detached(priority: .utility) {
                await self.savePhoto(data: data, projectId: projectId, pairId: pairId, isBefore: isBefore)
            }
        }
    }
}
