@preconcurrency import AVFoundation
import Foundation
import Observation
import SwiftUI
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
    let refillPairId: UUID?

    let session: CameraSession

    var lensPosition: CameraLensPosition = .back
    var flashMode: CameraFlashMode = .off {
        didSet {
            appSettings.cameraFlashMode = CameraFlashModeMapping.persisted(from: flashMode)
        }
    }

    var activePreset: ZoomPresetSpec?
    var availablePresets: [ZoomPresetSpec] = []
    var firstSwitchOver: Double = 1.0
    var displayMultiplier: Double = 1.0
    var minZoom: Double = 1
    var maxZoom: Double = 1
    var pinchBaseFactor: Double = 1.0
    var currentZoomRatio: Double = 1.0
    var isDraggingZoom: Bool = false
    var isGridOn: Bool = false {
        didSet { appSettings.cameraGridEnabled = isGridOn }
    }

    var isLevelOn: Bool = false {
        didSet { appSettings.cameraLevelEnabled = isLevelOn }
    }

    var isNightModeOn: Bool = false {
        didSet { appSettings.cameraNightMode = isNightModeOn }
    }

    var isCapturing: Bool = false
    var cameraPermissionState: CameraPermissionState = .unknown
    var captureErrorMessage: String?
    var cachedExposureRange: ClosedRange<Float>?

    var lastThumbnail: UIImage?
    var pendingPairs: [PhotoPair] = []
    var selectedPairId: UUID?

    let sortOrder: HomeSortOrder
    let events: AsyncStream<Event>

    private let createPair: CreatePairUseCase
    private let pairRepo: PhotoPairRepository
    private let albumRepo: AlbumRepository
    private let appSettings: AppSettings
    let hapticService: HapticService
    private let location: CoreLocationService
    private let permissionProbe: @Sendable () async -> Bool
    private let eventsContinuation: AsyncStream<Event>.Continuation
    private var dragAccumulatorPx: Double = 0
    private var dragStartRatio: Double = 1.0
    private var lastMinorTickIndex: Int?
    private var lastMajorTickIndex: Int?
    private var sessionStartedAt: Date = .distantPast
    private var zoomRampTask: Task<Void, Never>?
    private var pinchRampTask: Task<Void, Never>?

    nonisolated var captureSession: AVCaptureSession {
        session.captureSession
    }

    init(
        albumId: UUID?,
        createPair: CreatePairUseCase,
        pairRepo: PhotoPairRepository,
        albumRepo: AlbumRepository,
        appSettings: AppSettings,
        hapticService: HapticService,
        location: CoreLocationService,
        sortOrder: HomeSortOrder = .newest,
        refillPairId: UUID? = nil,
        session: CameraSession? = nil,
        permissionProbe: @escaping @Sendable () async -> Bool = CameraPermissionProbe.resolve
    ) {
        self.albumId = albumId
        self.refillPairId = refillPairId
        self.createPair = createPair
        self.pairRepo = pairRepo
        self.albumRepo = albumRepo
        self.appSettings = appSettings
        self.hapticService = hapticService
        self.location = location
        self.sortOrder = sortOrder
        let resolvedSession = session ?? CameraSession()
        self.session = resolvedSession
        self.permissionProbe = permissionProbe
        let stream = AsyncStream<Event>.makeStream()
        events = stream.stream
        eventsContinuation = stream.continuation
        isGridOn = appSettings.cameraGridEnabled
        isLevelOn = appSettings.cameraLevelEnabled
        isNightModeOn = appSettings.cameraNightMode
        flashMode = CameraFlashModeMapping.flashMode(from: appSettings.cameraFlashMode)
    }

    func onAppear() async {
        location.start()
        sessionStartedAt = .now
        pendingPairs = []
        async let permission = permissionProbe()
        async let startTask: Void = session.start()
        cameraPermissionState = await permission ? .granted : .denied
        guard cameraPermissionState == .granted else { return }
        _ = await startTask
        let snapshot = await session.zoomSnapshot()
        applyZoomSnapshot(snapshot)
        activePreset = matchingPreset(for: currentZoomRatio)
    }

    private func applyZoomSnapshot(_ snapshot: CameraZoomSnapshot) {
        minZoom = snapshot.minFactor
        maxZoom = snapshot.maxFactor
        currentZoomRatio = snapshot.currentFactor
        availablePresets = snapshot.presets
        firstSwitchOver = snapshot.firstSwitchOver
        displayMultiplier = snapshot.displayMultiplier
        cachedExposureRange = snapshot.exposureBiasRange
    }

    func onDisappear() {
        location.stop()
        Task { await session.stop() }
    }

    func onPinchChanged(_ scale: Double) {
        let target = pinchBaseFactor * scale
        currentZoomRatio = clampZoom(target)
        activePreset = matchingPreset(for: target)
        pinchRampTask?.cancel()
        pinchRampTask = Task { [session] in
            guard !Task.isCancelled else { return }
            await session.ramp(toZoomFactor: target, rate: 6.0)
        }
    }

    func onPinchEnded(_ scale: Double) {
        pinchBaseFactor *= scale
        pinchRampTask?.cancel()
        pinchRampTask = nil
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

    func toggleLens() {
        let next: CameraLensPosition = lensPosition == .back ? .front : .back
        Task {
            await session.switchLens(to: next)
            let snapshot = await session.zoomSnapshot()
            lensPosition = next
            applyZoomSnapshot(snapshot)
            pinchBaseFactor = snapshot.currentFactor
            activePreset = matchingPreset(for: pinchBaseFactor)
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

    func applyPreset(_ preset: ZoomPresetSpec) {
        activePreset = preset
        pinchBaseFactor = preset.factor
        currentZoomRatio = preset.factor
        Task { await session.ramp(toZoomFactor: preset.factor, rate: 32.0) }
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
        zoomRampTask?.cancel()
        zoomRampTask = Task { [session] in
            guard !Task.isCancelled else { return }
            await session.ramp(toZoomFactor: target, rate: 32.0)
        }
        emitTickHaptics(for: target)
    }

    func onZoomDragEnded() {
        isDraggingZoom = false
        pinchBaseFactor = currentZoomRatio
        lastMinorTickIndex = nil
        lastMajorTickIndex = nil
        zoomRampTask?.cancel()
        zoomRampTask = nil
    }

    func shutter() async {
        guard !isCapturing, session.captureReadiness == .ready else { return }
        isCapturing = true
        let captured: CapturedPhoto
        do {
            let metadata = ExifGPSBuilder.metadata(from: location.currentLocation)
            captured = try await session.capturePhoto(metadata: metadata)
        } catch {
            captureErrorMessage = Self.captureErrorText(for: error)
            isCapturing = false
            return
        }
        updateLastThumbnail(from: captured.jpegData)
        eventsContinuation.yield(.snackbarSuccess)
        isCapturing = false
        let lensPosition = LensPosition.resolve(identifier: captured.lensIdentifier)
        let cameraSettings = CameraSettings(zoomFactor: captured.zoomFactor, lensPosition: lensPosition)
        do {
            if let refillPairId {
                _ = try await createPair.refillBefore(
                    pairId: refillPairId,
                    beforeJPEG: captured.jpegData,
                    cameraSettings: cameraSettings,
                    isDeferredProxy: captured.isDeferredProxy
                )
                eventsContinuation.yield(.dismiss)
                return
            }
            let pair = try await createPair(
                beforeJPEG: captured.jpegData,
                cameraSettings: cameraSettings,
                isDeferredProxy: captured.isDeferredProxy
            )
            if let albumId {
                try? await albumRepo.addPair(pairId: pair.id, toAlbum: albumId)
            }
            let nextPairs = await fetchSortedPendingPairs()
            withAnimation(.smooth) {
                pendingPairs = nextPairs
                selectedPairId = pair.id
            }
        } catch {
            captureErrorMessage = Self.captureErrorText(for: error)
        }
    }

    private func updateLastThumbnail(from jpegData: Data) {
        guard let image = UIImage(data: jpegData) else { return }
        lastThumbnail = image
    }

    private func emitTickHaptics(for ratio: Double) {
        let minorIndex = Int((ratio * 10).rounded())
        if minorIndex != lastMinorTickIndex {
            lastMinorTickIndex = minorIndex
            hapticService.impact(.light)
        }
        let majorIndex = Int(ratio.rounded())
        if abs(ratio - Double(majorIndex)) < 0.05, majorIndex != lastMajorTickIndex {
            lastMajorTickIndex = majorIndex
            hapticService.impact(.medium)
        }
    }

    private func clampZoom(_ value: Double) -> Double {
        max(minZoom, min(value, maxZoom))
    }

    private func matchingPreset(for factor: Double) -> ZoomPresetSpec? {
        availablePresets.last { $0.factor <= factor + 0.05 } ?? availablePresets.first
    }

    static func captureErrorText(for error: Error) -> String {
        if error is CameraSessionError {
            return String(localized: "camera_error_capture_failed")
        }
        if error is CaptureAfterUseCase.CaptureAfterError {
            return String(localized: "camera_error_persist_failed")
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain || nsError.domain == NSPOSIXErrorDomain {
            return String(localized: "camera_error_no_disk_space")
        }
        return String(localized: "camera_error_unknown")
    }
}

enum ZoomDialMetrics {
    static let dragRangeSpanPt: Double = 600
}

nonisolated enum CameraFlashModeMapping {
    static func flashMode(from raw: String) -> CameraFlashMode {
        switch raw.uppercased() {
            case CameraFlashModePersistence.on:
                .on

            case CameraFlashModePersistence.auto:
                .auto

            case CameraFlashModePersistence.torch:
                .torch

            default:
                .off
        }
    }

    static func persisted(from mode: CameraFlashMode) -> String {
        switch mode {
            case .off:
                CameraFlashModePersistence.off

            case .on:
                CameraFlashModePersistence.on

            case .auto:
                CameraFlashModePersistence.auto

            case .torch:
                CameraFlashModePersistence.torch
        }
    }
}

private extension BeforeCameraViewModel {
    func fetchSortedPendingPairs() async -> [PhotoPair] {
        let all = await (try? pairRepo.fetchAll()) ?? []
        let scoped: [PhotoPair] = if let albumId {
            all.filter { $0.albumIds.contains(albumId) }
        } else { all }
        let filtered = scoped
            .filter { $0.afterPhotoLocalIdentifier == nil }
            .filter { $0.createdAt >= sessionStartedAt }
        return filtered.sorted { lhs, rhs in
            sortOrder == .newest ? lhs.createdAt > rhs.createdAt : lhs.createdAt < rhs.createdAt
        }
    }
}
