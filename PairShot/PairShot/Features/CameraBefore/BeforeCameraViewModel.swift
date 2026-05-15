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

    var currentAspect: AspectRatio = .default
    var isCapturing: Bool = false
    var cameraPermissionState: CameraPermissionState = .unknown
    var captureErrorMessage: String?
    var cachedExposureRange: ClosedRange<Float>?

    var lastThumbnail: UIImage?
    var pendingPairs: [PhotoPair] = []
    var selectedPairId: UUID?
    var showPaywall: Bool = false

    let sortOrder: HomeSortOrder
    let events: AsyncStream<Event>

    let createPair: CreatePairUseCase
    let pairRepo: PhotoPairRepository
    let albumRepo: AlbumRepository
    let appSettings: AppSettings
    let hapticService: HapticService
    let location: CoreLocationService
    let membership: Membership
    let permissionProbe: @Sendable () async -> Bool
    let eventsContinuation: AsyncStream<Event>.Continuation
    var dragAccumulatorPx: Double = 0
    var dragStartRatio: Double = 1.0
    var lastMinorTickIndex: Int?
    var lastMajorTickIndex: Int?
    var sessionStartedAt: Date = .distantPast
    var zoomRampTask: Task<Void, Never>?
    var pinchRampTask: Task<Void, Never>?

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
        membership: Membership,
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
        self.membership = membership
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
        currentAspect = appSettings.cameraAspectRatio
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
        await session.setAspectRatio(currentAspect)
        let snapshot = await session.zoomSnapshot()
        applyZoomSnapshot(snapshot)
        activePreset = matchingPreset(for: currentZoomRatio)
    }

    func applyZoomSnapshot(_ snapshot: CameraZoomSnapshot) {
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
