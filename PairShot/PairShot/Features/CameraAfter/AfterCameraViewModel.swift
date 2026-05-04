@preconcurrency import AVFoundation
import Foundation
import ImageIO
import Observation
import OSLog

// swiftlint:disable type_contents_order switch_case_alignment

@MainActor
@Observable
final class AfterCameraViewModel {
    enum Event {
        case dismiss
        case snackbarSuccess
        case snackbarAllCompleted
    }

    let albumId: UUID?
    let initialPairId: UUID?
    let sortOrder: HomeSortOrder

    let session: CameraSession

    var pairs: [PhotoPair] = []
    var selectedPairId: UUID?
    var currentPair: PhotoPair?
    var ghostImageData: Data?
    var alpha: Double = GhostOverlayMath.defaultAlpha {
        didSet { appSettings.defaultOverlayAlpha = alpha }
    }

    var overlayEnabled: Bool = true {
        didSet { appSettings.overlayEnabled = overlayEnabled }
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
    var isCapturing: Bool = false
    var hasRestoredZoom: Bool = false
    var cameraPermissionGranted: Bool?
    var captureErrorMessage: String?
    var ghostWarningToast: String?

    var isGridOn: Bool = false {
        didSet { appSettings.cameraGridEnabled = isGridOn }
    }

    var isLevelOn: Bool = false {
        didSet { appSettings.cameraLevelEnabled = isLevelOn }
    }

    var isNightModeOn: Bool = false {
        didSet { appSettings.cameraNightMode = isNightModeOn }
    }

    var flashMode: CameraFlashMode = .off {
        didSet {
            appSettings.cameraFlashMode = CameraFlashModeMapping.persisted(from: flashMode)
        }
    }

    var lensPosition: CameraLensPosition = .back

    var rotationDirection: RotationGuideDirection = .upright
    var ghostRotationDegrees: Double = 0
    var allCompleted: Bool = false

    var pendingPairCount: Int = 0
    var completedPairCount: Int = 0

    let events: AsyncStream<Event>

    let zoomDragState: AfterCameraZoomDragState = .init()

    private let captureAfter: CaptureAfterUseCase
    private let pairRepo: PhotoPairRepository
    private let photoLibrary: PhotoLibraryService
    private let appSettings: AppSettings
    let hapticService: HapticService
    private let captureSource: AfterCameraCaptureSource
    private let permissionProbe: @Sendable () async -> Bool
    private let eventsContinuation: AsyncStream<Event>.Continuation
    private var allCompletedDismissTask: Task<Void, Never>?
    let motionService: MotionService = .init()

    init(
        albumId: UUID?,
        initialPairId: UUID? = nil,
        sortOrder: HomeSortOrder = .newest,
        captureAfter: CaptureAfterUseCase,
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        appSettings: AppSettings,
        hapticService: HapticService,
        session: CameraSession? = nil,
        captureSource: AfterCameraCaptureSource? = nil,
        permissionProbe: @escaping @Sendable () async -> Bool = AfterCameraPermissionProbe.resolve
    ) {
        self.albumId = albumId
        self.initialPairId = initialPairId
        self.sortOrder = sortOrder
        self.captureAfter = captureAfter
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.appSettings = appSettings
        self.hapticService = hapticService
        let resolvedSession = session ?? CameraSession()
        self.session = resolvedSession
        self.captureSource = captureSource ?? AfterCameraSessionCaptureSource(session: resolvedSession)
        self.permissionProbe = permissionProbe
        var continuation: AsyncStream<Event>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventsContinuation = continuation
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)
        overlayEnabled = appSettings.overlayEnabled
        isGridOn = appSettings.cameraGridEnabled
        isLevelOn = appSettings.cameraLevelEnabled
        isNightModeOn = appSettings.cameraNightMode
        flashMode = CameraFlashModeMapping.flashMode(from: appSettings.cameraFlashMode)
    }

    nonisolated var captureSession: AVCaptureSession {
        session.captureSession
    }

    func onAppear() async {
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)
        motionService.start()
        async let permission = permissionProbe()
        async let startTask: Void = session.start()
        cameraPermissionGranted = await permission
        guard cameraPermissionGranted == true else { return }
        _ = await startTask
        let snapshot = await session.zoomSnapshot()
        applyZoomSnapshot(snapshot)
        await loadPendingScopeAndStart()
    }

    func applyZoomSnapshot(_ snapshot: CameraZoomSnapshot) {
        minZoom = snapshot.minFactor
        maxZoom = snapshot.maxFactor
        currentZoomRatio = snapshot.currentFactor
        availablePresets = snapshot.presets
        firstSwitchOver = snapshot.firstSwitchOver
        displayMultiplier = snapshot.displayMultiplier
    }

    func onDisappear() {
        allCompletedDismissTask?.cancel()
        allCompletedDismissTask = nil
        motionService.stop()
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

    func onSelectionChanged(_ newId: UUID?) {
        guard let newId else { return }
        guard newId != currentPair?.id else { return }
        guard let pair = pairs.first(where: { $0.id == newId }) else { return }
        adopt(pair: pair)
    }

    var deviceRotationDegrees: Double = 90 {
        didSet { recomputeRotationDirection() }
    }

    var beforeExifOrientation: CGImagePropertyOrientation = .up
    var beforeCaptureAngle: Double = 90 {
        didSet { recomputeRotationDirection() }
    }

    func updateDeviceRotation(degrees: Double) {
        let captureAngleSnapshot = beforeCaptureAngle
        AppLogger.camera
            .info(
                "[CAM-ROT-DEV] updateDeviceRotation: degrees=\(degrees, privacy: .public), beforeCaptureAngle=\(captureAngleSnapshot, privacy: .public)"
            )
        deviceRotationDegrees = degrees
    }

    private func recomputeRotationDirection() {
        let captureAngleSnapshot = beforeCaptureAngle
        let deviceAngleSnapshot = deviceRotationDegrees
        let delta = RotationGuideResolver.displayDelta(
            captureAngleDegrees: captureAngleSnapshot,
            deviceAngleDegrees: deviceAngleSnapshot
        )
        let ghost = -delta
        ghostRotationDegrees = ghost
        let direction = RotationGuideResolver.direction(
            captureAngleDegrees: captureAngleSnapshot,
            deviceAngleDegrees: deviceAngleSnapshot
        )
        AppLogger.camera
            .info(
                "[CAM-ROT-RES] rotationDirection=\(String(describing: direction), privacy: .public), ghostRotation=\(ghost, privacy: .public), beforeCaptureAngle=\(captureAngleSnapshot, privacy: .public), deviceAngle=\(deviceAngleSnapshot, privacy: .public)"
            )
        rotationDirection = direction
    }

    func dismiss() {
        eventsContinuation.yield(.dismiss)
    }

    func shutter() async {
        guard !isCapturing, let pair = currentPair else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let captured = try await captureSource.capturePhoto()
            let updated = try await captureAfter(
                pairId: pair.id,
                afterJPEG: captured.jpegData,
                jpegQuality: appSettings.jpegQuality
            )
            currentPair = updated
            eventsContinuation.yield(.snackbarSuccess)
            await advanceToNextOrFinish(after: updated)
        } catch {
            captureErrorMessage = Self.captureErrorText(for: error)
        }
    }

    private func loadPendingScopeAndStart() async {
        await refreshPairs()
        guard let initialPair = AfterCameraInitialPairResolver.resolve(
            initialPairId: initialPairId,
            pending: pairs
        ) else {
            eventsContinuation.yield(.dismiss)
            return
        }
        adopt(pair: initialPair)
    }

    private func advanceToNextOrFinish(after _: PhotoPair) async {
        await refreshPairs()
        if let next = pairs.first {
            adopt(pair: next)
        } else {
            currentPair = nil
            ghostImageData = nil
            allCompleted = true
            eventsContinuation.yield(.snackbarAllCompleted)
            scheduleAllCompletedDismiss()
        }
    }

    private func scheduleAllCompletedDismiss() {
        allCompletedDismissTask?.cancel()
        allCompletedDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, !Task.isCancelled else { return }
            eventsContinuation.yield(.dismiss)
        }
    }

    private func adopt(pair: PhotoPair) {
        currentPair = pair
        selectedPairId = pair.id
        ghostImageData = nil
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)
        hasRestoredZoom = false
        beforeCaptureAngle = pair.cameraSettings?.captureAngleDegrees ?? 90
        Task { await loadGhost(for: pair) }
        Task { await restoreZoom(for: pair) }
    }

    private func loadGhost(for pair: PhotoPair) async {
        guard let identifier = pair.beforePhotoLocalIdentifier, !identifier.isEmpty else {
            ghostWarningToast = String(localized: "after_ghost_missing_warning")
            return
        }
        let library = photoLibrary
        let loaded = await library.requestImageData(localIdentifier: identifier)
        guard currentPair?.id == pair.id else { return }
        ghostImageData = loaded
        if loaded == nil {
            ghostWarningToast = String(localized: "after_ghost_missing_warning")
        }
    }

    private func restoreZoom(for pair: PhotoPair) async {
        guard !hasRestoredZoom else { return }
        let target = pair.cameraSettings?.zoomFactor ?? 1.0
        await session.setZoomFactor(target)
        let actual = await session.currentZoomFactor
        pinchBaseFactor = actual
        currentZoomRatio = actual
        activePreset = AfterCameraZoomPresetMatcher.match(actual, in: availablePresets)
        hasRestoredZoom = true
    }

    private func refreshPairs() async {
        let snapshot = await AfterCameraScopeFetch(pairRepo: pairRepo, albumId: albumId)
            .fetch(initialPairId: initialPairId, sortOrder: sortOrder)
        pairs = snapshot.pending
        pendingPairCount = snapshot.pending.count
        completedPairCount = snapshot.completedCount
    }

    static func captureErrorText(for error: Error) -> String {
        AfterCameraCaptureErrorMessages.text(for: error)
    }
}

enum AfterCameraCaptureErrorMessages {
    static func text(for error: Error) -> String {
        if error is CameraSessionError {
            return String(localized: "camera_error_capture_failed")
        }
        if let captureAfter = error as? CaptureAfterUseCase.CaptureAfterError {
            switch captureAfter {
                case .pairNotFound:
                    return String(localized: "camera_error_persist_failed")
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain || nsError.domain == NSPOSIXErrorDomain {
            return String(localized: "camera_error_no_disk_space")
        }
        return String(localized: "camera_error_unknown")
    }
}

protocol AfterCameraCaptureSource: Sendable {
    func capturePhoto() async throws -> CapturedPhoto
}

struct AfterCameraSessionCaptureSource: AfterCameraCaptureSource {
    let session: CameraSession

    func capturePhoto() async throws -> CapturedPhoto {
        try await session.capturePhoto()
    }
}

enum AfterCameraPermissionProbe {
    @Sendable
    static func resolve() async -> Bool {
        let service = await MainActor.run { PermissionStatusService() }
        return await service.requestCameraAccessIfNeeded()
    }
}

enum AfterCameraZoomHaptics {
    struct Result {
        let minorIndex: Int
        let majorIndex: Int
        let didCrossMinor: Bool
        let didCrossMajor: Bool
    }

    static func evaluate(ratio: Double, lastMinorIndex: Int?, lastMajorIndex: Int?) -> Result {
        let minorIndex = Int((ratio * 10).rounded())
        let majorIndex = Int(ratio.rounded())
        let didCrossMinor = minorIndex != lastMinorIndex
        let nearMajor = abs(ratio - Double(majorIndex)) < 0.05
        let didCrossMajor = nearMajor && majorIndex != lastMajorIndex
        return Result(
            minorIndex: minorIndex,
            majorIndex: majorIndex,
            didCrossMinor: didCrossMinor,
            didCrossMajor: didCrossMajor
        )
    }
}

@MainActor
enum AfterCameraGhostLoader {
    static func loadData(localIdentifier: String, photoLibrary: PhotoLibraryService) async -> Data? {
        guard !localIdentifier.isEmpty else { return nil }
        return await photoLibrary.requestImageData(localIdentifier: localIdentifier)
    }
}

// swiftlint:enable type_contents_order switch_case_alignment
