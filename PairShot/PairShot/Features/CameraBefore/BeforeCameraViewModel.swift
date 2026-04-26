@preconcurrency import AVFoundation
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class BeforeCameraViewModel {
    enum Event {
        case dismiss
        case snackbarSuccess
        case openAfterCamera(pairId: UUID)
    }

    let albumId: UUID?

    let session: CameraSession

    var lensPosition: CameraLensPosition = .back
    var flashMode: CameraFlashMode = .off
    var activePreset: ZoomPreset?
    var minZoom: Double = 1
    var maxZoom: Double = 1
    var pinchBaseFactor: Double = 1.0
    var currentZoomRatio: Double = 1.0
    var isDraggingZoom: Bool = false
    var isGridOn: Bool = false
    var isLevelOn: Bool = false
    var isNightModeOn: Bool = false
    var isCapturing: Bool = false
    var showSettingsSheet: Bool = false
    var cameraPermissionGranted: Bool?
    var captureErrorMessage: String?
    var cachedExposureRange: ClosedRange<Float>?

    var lastThumbnail: UIImage?
    var pendingPairs: [PhotoPair] = []

    let events: AsyncStream<Event>

    private let createPair: CreatePairUseCase
    private let pairRepo: PhotoPairRepository
    private let storage: PhotoStoring
    private let albumRepo: AlbumRepository
    private let appSettings: AppSettings
    private let captureSource: BeforeCameraCaptureSource
    private let permissionProbe: @Sendable () async -> Bool
    private let eventsContinuation: AsyncStream<Event>.Continuation
    private var supportedPresets: Set<ZoomPreset> = []
    private var dragAccumulatorPx: Double = 0
    private var dragStartRatio: Double = 1.0
    private var lastMinorTickIndex: Int?
    private var lastMajorTickIndex: Int?

    init(
        albumId: UUID?,
        createPair: CreatePairUseCase,
        pairRepo: PhotoPairRepository,
        storage: PhotoStoring,
        albumRepo: AlbumRepository,
        appSettings: AppSettings,
        session: CameraSession? = nil,
        captureSource: BeforeCameraCaptureSource? = nil,
        permissionProbe: @escaping @Sendable () async -> Bool = BeforeCameraPermissionProbe.resolve
    ) {
        self.albumId = albumId
        self.createPair = createPair
        self.pairRepo = pairRepo
        self.storage = storage
        self.albumRepo = albumRepo
        self.appSettings = appSettings
        let resolvedSession = session ?? CameraSession()
        self.session = resolvedSession
        self.captureSource = captureSource ?? CameraSessionCaptureSource(session: resolvedSession)
        self.permissionProbe = permissionProbe
        activePreset = .wide
        var continuation: AsyncStream<Event>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventsContinuation = continuation
    }

    nonisolated var captureSession: AVCaptureSession {
        session.captureSession
    }

    nonisolated func isPresetSupported(_ preset: ZoomPreset) -> Bool {
        MainActor.assumeIsolated { supportedPresets.contains(preset) }
    }

    func onAppear() async {
        cameraPermissionGranted = await permissionProbe()
        guard cameraPermissionGranted == true else { return }
        await session.start()
        await refreshCapabilities()
        minZoom = await session.minZoomFactor
        maxZoom = await session.maxZoomFactor
        currentZoomRatio = await session.currentZoomFactor
        await refreshPendingPairs()
    }

    func onDisappear() {
        Task { await session.stop() }
    }

    func handleScenePhaseAction(_ action: CameraSessionAction?) {
        guard cameraPermissionGranted == true else { return }
        switch action {
            case .stop:
                Task { await session.stop() }

            case .start:
                Task { await session.start() }

            case nil:
                break
        }
    }

    func onPinchChanged(_ scale: Double) {
        let target = pinchBaseFactor * scale
        Task { await session.ramp(toZoomFactor: target, rate: 6.0) }
        currentZoomRatio = clampZoom(target)
        activePreset = matchingPreset(for: target)
    }

    func onPinchEnded(_ scale: Double) {
        pinchBaseFactor *= scale
    }

    func onTapFocus(devicePoint: CGPoint) {
        Task { await session.focus(at: devicePoint) }
    }

    func onExposureBias(_ bias: Float) {
        Task { await session.setExposureBias(bias) }
    }

    func cycleFlash() {
        Task {
            let next = await session.cycleFlashMode()
            flashMode = next
        }
    }

    func setFlashMode(_ mode: CameraFlashMode) {
        guard mode != flashMode else { return }
        flashMode = mode
        Task { await session.setFlashMode(mode) }
    }

    func toggleLens() {
        let next: CameraLensPosition = lensPosition == .back ? .front : .back
        Task {
            await session.switchLens(to: next)
            await refreshCapabilities()
            lensPosition = next
            minZoom = await session.minZoomFactor
            maxZoom = await session.maxZoomFactor
            pinchBaseFactor = await session.currentZoomFactor
            currentZoomRatio = pinchBaseFactor
            activePreset = matchingPreset(for: pinchBaseFactor) ?? .wide
        }
    }

    func toggleGrid() {
        isGridOn.toggle()
    }

    func toggleLevel() {
        isLevelOn.toggle()
    }

    func toggleNightMode() {
        isNightModeOn.toggle()
        let enabled = isNightModeOn
        Task { await session.setLowLightBoost(enabled: enabled) }
    }

    func applyPreset(_ preset: ZoomPreset) {
        activePreset = preset
        pinchBaseFactor = preset.factor
        currentZoomRatio = preset.factor
        Task { await session.setZoomFactor(preset.factor) }
    }

    func onZoomDragBegan() {
        if !isDraggingZoom {
            dragAccumulatorPx = 0
            dragStartRatio = currentZoomRatio
            lastMinorTickIndex = Int((currentZoomRatio * 10).rounded())
            lastMajorTickIndex = Int(currentZoomRatio.rounded())
            isDraggingZoom = true
        }
    }

    func onZoomDragChanged(deltaPx: Double) {
        onZoomDragBegan()
        dragAccumulatorPx = deltaPx
        let span = max(maxZoom - minZoom, 0.0001)
        let pxPerZoom = ZoomDialMetrics.dragRangeSpanPt / span
        let zoomDelta = dragAccumulatorPx / pxPerZoom
        let target = clampZoom(dragStartRatio + zoomDelta)
        currentZoomRatio = target
        activePreset = matchingPreset(for: target)
        Task { await session.ramp(toZoomFactor: target, rate: 6.0) }
        emitTickHaptics(for: target)
    }

    func onZoomDragEnded() {
        isDraggingZoom = false
        pinchBaseFactor = currentZoomRatio
        lastMinorTickIndex = nil
        lastMajorTickIndex = nil
    }

    func onSettingsTap() {
        showSettingsSheet = true
    }

    func onStripPairTap(_ pair: PhotoPair) {
        eventsContinuation.yield(.openAfterCamera(pairId: pair.id))
    }

    func dismiss() {
        eventsContinuation.yield(.dismiss)
    }

    func shutter() async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let captured = try await captureSource.capturePhoto()
            let cameraSettings = CameraSettings(
                zoomFactor: captured.zoomFactor,
                lensPosition: V1ToV2Migrator.lensPosition(for: captured.lensIdentifier),
                flashMode: BeforeCameraFlashModeMapper.persisted(from: flashMode),
                useGrid: isGridOn,
                useNightMode: isNightModeOn
            )
            let prefix = FileNamePrefixValidator.sanitize(appSettings.fileNamePrefix)
            let pair = try await createPair(
                beforeJPEG: captured.jpegData,
                prefix: prefix,
                cameraSettings: cameraSettings,
                jpegQuality: appSettings.jpegQuality
            )
            if let albumId {
                try? await albumRepo.addPair(pairId: pair.id, toAlbum: albumId)
            }
            await refreshPendingPairs()
            updateLastThumbnail(from: captured.jpegData)
            eventsContinuation.yield(.snackbarSuccess)
        } catch {
            captureErrorMessage = Self.captureErrorText(for: error)
        }
    }

    private func updateLastThumbnail(from jpegData: Data) {
        guard let image = UIImage(data: jpegData) else { return }
        lastThumbnail = image
    }

    private func refreshPendingPairs() async {
        let all = await (try? pairRepo.fetchAll()) ?? []
        let scoped: [PhotoPair] = if let albumId {
            all.filter { $0.albums.contains(where: { $0.id == albumId }) }
        } else {
            all
        }
        pendingPairs = scoped
            .filter { $0.afterFileName == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func emitTickHaptics(for ratio: Double) {
        let minorIndex = Int((ratio * 10).rounded())
        if minorIndex != lastMinorTickIndex {
            lastMinorTickIndex = minorIndex
            HapticService.shared.impact(.light)
        }
        let majorIndex = Int(ratio.rounded())
        if abs(ratio - Double(majorIndex)) < 0.05, majorIndex != lastMajorTickIndex {
            lastMajorTickIndex = majorIndex
            HapticService.shared.impact(.medium)
        }
    }

    private func clampZoom(_ value: Double) -> Double {
        max(minZoom, min(value, maxZoom))
    }

    private func refreshCapabilities() async {
        cachedExposureRange = await session.exposureBiasRange
        var supported: Set<ZoomPreset> = []
        for preset in ZoomPreset.allCases where await session.isPresetSupported(preset) {
            supported.insert(preset)
        }
        supportedPresets = supported
    }

    private func matchingPreset(for factor: Double) -> ZoomPreset? {
        let tolerance = 0.05
        return ZoomPreset.allCases.first { abs($0.factor - factor) <= tolerance }
    }

    static func captureErrorText(for error: Error) -> String {
        if error is CameraSessionError {
            return String(localized: "카메라에서 사진을 가져올 수 없습니다. 다시 시도해 주세요.")
        }
        if error is CaptureAfterUseCase.CaptureAfterError {
            return String(localized: "사진 정보를 저장하지 못했습니다. 다시 시도해 주세요.")
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain || nsError.domain == NSPOSIXErrorDomain {
            return String(localized: "사진을 저장할 공간이 부족합니다.")
        }
        return String(localized: "촬영을 완료할 수 없습니다. 잠시 후 다시 시도해 주세요.")
    }

    deinit {}
}

enum ZoomDialMetrics {
    static let dragRangeSpanPt: Double = 300
    static let pixelsPerMinorTick: Double = 30
}

enum BeforeCameraFlashModeMapper {
    static func persisted(from camera: CameraFlashMode) -> FlashMode {
        switch camera {
            case .off:
                .off

            case .on:
                .on

            case .auto:
                .auto

            case .torch:
                .torch
        }
    }
}

protocol BeforeCameraCaptureSource: Sendable {
    func capturePhoto() async throws -> CapturedPhoto
}

struct CameraSessionCaptureSource: BeforeCameraCaptureSource {
    let session: CameraSession

    func capturePhoto() async throws -> CapturedPhoto {
        try await session.capturePhoto()
    }
}

enum BeforeCameraPermissionProbe {
    @Sendable
    static func resolve() async -> Bool {
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
