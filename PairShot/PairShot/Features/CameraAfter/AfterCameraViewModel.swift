@preconcurrency import AVFoundation
import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

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
    let recaptureTargetPair: PhotoPair?

    var isRecaptureMode: Bool {
        recaptureTargetPair != nil
    }

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
    var cameraPermissionState: CameraPermissionState = .unknown
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
    var currentAspect: AspectRatio = .default

    var allCompleted: Bool = false

    var pendingPairCount: Int = 0
    var completedPairCount: Int = 0

    let events: AsyncStream<Event>

    let zoomDragState: AfterCameraZoomDragState = .init()

    private let captureAfter: CaptureAfterUseCase
    private let recaptureAfter: RecaptureAfterUseCase
    private let pairRepo: PhotoPairRepository
    private let photoLibrary: PhotoLibraryService
    private let appSettings: AppSettings
    let hapticService: HapticService
    private let location: CoreLocationService
    private let permissionProbe: @Sendable () async -> Bool
    private let eventsContinuation: AsyncStream<Event>.Continuation
    private var allCompletedDismissTask: Task<Void, Never>?

    nonisolated var captureSession: AVCaptureSession {
        session.captureSession
    }

    init(
        albumId: UUID?,
        captureAfter: CaptureAfterUseCase,
        recaptureAfter: RecaptureAfterUseCase,
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        appSettings: AppSettings,
        hapticService: HapticService,
        location: CoreLocationService,
        initialPairId: UUID? = nil,
        sortOrder: HomeSortOrder = .newest,
        recaptureTargetPair: PhotoPair? = nil,
        session: CameraSession? = nil,
        permissionProbe: @escaping @Sendable () async -> Bool = CameraPermissionProbe.resolve,
    ) {
        self.albumId = albumId
        self.initialPairId = initialPairId
        self.sortOrder = sortOrder
        self.recaptureTargetPair = recaptureTargetPair
        self.captureAfter = captureAfter
        self.recaptureAfter = recaptureAfter
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.appSettings = appSettings
        self.hapticService = hapticService
        self.location = location
        let resolvedSession = session ?? CameraSession()
        self.session = resolvedSession
        self.permissionProbe = permissionProbe
        let stream = AsyncStream<Event>.makeStream()
        events = stream.stream
        eventsContinuation = stream.continuation
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)
        overlayEnabled = appSettings.overlayEnabled
        isGridOn = appSettings.cameraGridEnabled
        isLevelOn = appSettings.cameraLevelEnabled
        isNightModeOn = appSettings.cameraNightMode
        flashMode = CameraFlashModeMapping.flashMode(from: appSettings.cameraFlashMode)
    }

    func onAppear() async {
        location.start()
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)
        async let permission = permissionProbe()
        async let startTask: Void = session.start()
        cameraPermissionState = await permission ? .granted : .denied
        guard cameraPermissionState == .granted else { return }
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
        location.stop()
        allCompletedDismissTask?.cancel()
        allCompletedDismissTask = nil
        Task { await session.stop() }
    }

    func onSelectionChanged(_ newId: UUID?) {
        guard let newId else { return }
        guard newId != currentPair?.id else { return }
        guard let pair = pairs.first(where: { $0.id == newId }) else { return }
        adopt(pair: pair)
    }

    func shutter() async {
        guard !isCapturing, session.captureReadiness == .ready, let pair = currentPair else { return }
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
        eventsContinuation.yield(.snackbarSuccess)
        let capturedPairId = pair.id

        contractPairsAndAdvance(removing: capturedPairId)
        isCapturing = false

        do {
            _ = try await persistAfter(
                pairId: capturedPairId,
                afterData: captured.data,
                afterUTType: captured.utType,
                aspectRatio: currentAspect,
                isDeferredProxy: captured.isDeferredProxy,
            )
        } catch {
            rollbackOnPersistFailure(pair)
            captureErrorMessage = Self.captureErrorText(for: error)
        }
    }

    private func contractPairsAndAdvance(removing capturedPairId: UUID) {
        if isRecaptureMode {
            withAnimation(.smooth) {
                currentPair = nil
                ghostImageData = nil
                allCompleted = true
            }
            eventsContinuation.yield(.dismiss)
            return
        }
        let capturedIndex = pairs.firstIndex(where: { $0.id == capturedPairId }) ?? 0
        withAnimation(.smooth) {
            pairs.removeAll { $0.id == capturedPairId }
            pendingPairCount = max(0, pendingPairCount - 1)
            completedPairCount += 1
            if pairs.isEmpty {
                currentPair = nil
                ghostImageData = nil
                allCompleted = true
            } else {
                let targetIndex = min(capturedIndex, pairs.count - 1)
                adopt(pair: pairs[targetIndex])
            }
        }
        if allCompleted {
            eventsContinuation.yield(.snackbarAllCompleted)
            scheduleAllCompletedDismiss()
        }
    }

    private func rollbackOnPersistFailure(_ pair: PhotoPair) {
        guard !pairs.contains(where: { $0.id == pair.id }) else { return }
        pairs.append(pair)
        pendingPairCount += 1
        completedPairCount = max(0, completedPairCount - 1)
    }

    private func persistAfter(
        pairId: UUID,
        afterData: Data,
        afterUTType: UTType,
        aspectRatio: AspectRatio,
        isDeferredProxy: Bool,
    ) async throws -> PhotoPair {
        if isRecaptureMode {
            return try await recaptureAfter(
                pairId: pairId,
                afterData: afterData,
                afterUTType: afterUTType,
                aspectRatio: aspectRatio,
                isDeferredProxy: isDeferredProxy,
            )
        }
        return try await captureAfter(
            pairId: pairId,
            afterData: afterData,
            afterUTType: afterUTType,
            aspectRatio: aspectRatio,
            isDeferredProxy: isDeferredProxy,
        )
    }

    private func loadPendingScopeAndStart() async {
        if let target = recaptureTargetPair {
            pairs = [target]
            pendingPairCount = 1
            completedPairCount = 0
            adopt(pair: target)
            return
        }
        await refreshPairs()
        guard
            let initialPair = AfterCameraInitialPairResolver.resolve(
                initialPairId: initialPairId,
                pending: pairs,
            )
        else {
            eventsContinuation.yield(.dismiss)
            return
        }
        adopt(pair: initialPair)
    }

    private func scheduleAllCompletedDismiss() {
        allCompletedDismissTask?.cancel()
        allCompletedDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
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
        let resolvedAspect = pair.cameraSettings?.resolvedAspectRatio ?? .default
        currentAspect = resolvedAspect
        Task { await session.setAspectRatio(resolvedAspect) }
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
            didCrossMajor: didCrossMajor,
        )
    }
}
