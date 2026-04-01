@preconcurrency import AVFoundation
import CoreImage
import ImageIO
import MobileCoreServices
import Observation
import UIKit

/// AVCaptureSession 전체 생명주기를 책임지는 서비스.
///
/// - 모든 AVFoundation 설정·변경은 `sessionQueue`(serial background queue)에서 실행한다.
/// - `@Observable` 프로퍼티 업데이트는 반드시 `@MainActor`로 전환한다.
/// - 권한 요청은 절대 init에서 하지 않는다 (just-in-time).
@Observable
@MainActor
final class CameraManager: NSObject, CameraServiceProtocol {
    private(set) var isSessionRunning: Bool = false
    private(set) var isCameraAuthorized: Bool = false
    private(set) var capturedPhoto: UIImage?

    // nonisolated(unsafe): sessionQueue에서만 접근하므로 안전 — Swift 6 Sendable 경고 억제
    @ObservationIgnored
    nonisolated(unsafe) private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.pairshot.camera.sessionQueue", qos: .userInitiated)

    @ObservationIgnored
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?
    @ObservationIgnored
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    @ObservationIgnored
    nonisolated(unsafe) private var currentCameraPosition: AVCaptureDevice.Position = .back

    private var pendingProjectId: UUID?
    private var pendingPairId: UUID?

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

    func capturePhoto(projectId: UUID, pairId: UUID) {
        pendingProjectId = projectId
        pendingPairId = pairId

        let settings = makePhotoSettings()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    struct ZoomInfo {
        let minFactor: CGFloat
        let maxFactor: CGFloat
        let displayMultiplier: CGFloat                    // videoZoomFactor * multiplier = 표시값
        let switchOverFactors: [CGFloat]                  // 렌즈 전환 포인트
        let secondaryNativeResolutionZoomFactors: [CGFloat] // 2x 크롭 등 네이티브 해상도 포인트
        let defaultFactor: CGFloat                        // 1x에 해당하는 zoomFactor
    }

    func getZoomInfo() -> ZoomInfo {
        guard let device = videoDeviceInput?.device else {
            return ZoomInfo(
                minFactor: 1.0, maxFactor: 1.0, displayMultiplier: 1.0,
                switchOverFactors: [], secondaryNativeResolutionZoomFactors: [], defaultFactor: 1.0
            )
        }
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        // secondaryNativeResolutionZoomFactors (iOS 16+): 2x 크롭 같은 네이티브 고해상도 줌 포인트
        // AVCaptureDeviceFormat 프로퍼티 — activeFormat에서 읽는다
        let secondaryNative = device.activeFormat.secondaryNativeResolutionZoomFactors
        // displayVideoZoomFactorMultiplier (iOS 18+): Apple 시스템 UI와 동일한 표시 배율 계산용
        let multiplier = device.displayVideoZoomFactorMultiplier
        // 1x = displayMultiplier 적용 시 1.0이 되는 zoomFactor
        let defaultZoom: CGFloat = multiplier > 0 ? (1.0 / multiplier) : (switchOvers.first ?? 1.0)
        return ZoomInfo(
            minFactor: device.minAvailableVideoZoomFactor,
            maxFactor: device.maxAvailableVideoZoomFactor,
            displayMultiplier: multiplier,
            switchOverFactors: switchOvers,
            secondaryNativeResolutionZoomFactors: secondaryNative,
            defaultFactor: defaultZoom
        )
    }

    /// 버튼 탭: `ramp(toVideoZoomFactor:withRate:)` 로 부드럽게 전환
    func setZoom(factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let clamped = max(device.minAvailableVideoZoomFactor,
                                  min(factor, device.maxAvailableVideoZoomFactor))
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
            let clamped = max(device.minAvailableVideoZoomFactor,
                              min(factor, device.maxAvailableVideoZoomFactor))
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {}
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
            pendingProjectId = nil
            pendingPairId = nil

            if let image = UIImage(data: data) {
                capturedPhoto = image
            }

            Task.detached(priority: .utility) {
                await self.savePhoto(data: data, projectId: projectId, pairId: pairId)
            }
        }
    }

    private func savePhoto(data: Data, projectId: UUID?, pairId: UUID?) async {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        // 경로: Documents/projects/{projectId}/pairs/{pairId}/before.jpg
        // projectId / pairId가 없으면 임시 UUID 사용 (독립 캡처 시나리오)
        let resolvedProject = projectId ?? UUID()
        let resolvedPair = pairId ?? UUID()

        let pairDirectory = documentsURL
            .appendingPathComponent("projects")
            .appendingPathComponent(resolvedProject.uuidString)
            .appendingPathComponent("pairs")
            .appendingPathComponent(resolvedPair.uuidString)

        do {
            try fileManager.createDirectory(at: pairDirectory, withIntermediateDirectories: true)
        } catch {
            return
        }

        let photoURL = pairDirectory.appendingPathComponent("before.jpg")

        // HEIC → JPEG 변환 후 저장 (범용 호환성 + 명세 파일명 준수)
        let jpegData: Data = if let image = UIImage(data: data),
                                let converted = image.jpegData(compressionQuality: 0.92)
        {
            converted
        } else {
            data
        }

        do {
            try jpegData.write(to: photoURL, options: .atomic)
        } catch {
            return
        }

        // iOS 사진 라이브러리에도 저장
        if let image = UIImage(data: jpegData) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }

        await generateThumbnail(
            sourceURL: photoURL,
            projectId: resolvedProject,
            pairId: resolvedPair,
            documentsURL: documentsURL
        )
    }

    private func generateThumbnail(
        sourceURL: URL,
        projectId: UUID,
        pairId: UUID,
        documentsURL: URL
    ) async {
        let fileManager = FileManager.default

        // 경로: Documents/projects/{projectId}/thumbs/{pairId}_before.jpg
        let thumbDirectory = documentsURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId.uuidString)
            .appendingPathComponent("thumbs")

        do {
            try fileManager.createDirectory(at: thumbDirectory, withIntermediateDirectories: true)
        } catch {
            return
        }

        let thumbURL = thumbDirectory.appendingPathComponent("\(pairId.uuidString)_before.jpg")

        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, sourceOptions as CFDictionary) else {
            return
        }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: 300,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
        ]

        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return
        }

        let thumbImage = UIImage(cgImage: cgThumb)
        guard let thumbData = thumbImage.jpegData(compressionQuality: 0.85) else { return }

        try? thumbData.write(to: thumbURL, options: .atomic)
    }
}
