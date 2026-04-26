@preconcurrency import AVFoundation
import Foundation
import Observation
import UIKit

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
    let retakeMode: Bool

    let session: CameraSession

    var pairs: [PhotoPair] = []
    var selectedPairId: UUID?
    var currentPair: PhotoPair?
    var ghostImageData: Data?
    var alpha: Double = GhostOverlayMath.defaultAlpha
    var overlayEnabled: Bool = true
    var activePreset: ZoomPreset?
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

    var isGridOn: Bool = false
    var isLevelOn: Bool = false
    var isNightModeOn: Bool = false
    var flashMode: CameraFlashMode = .off
    var lensPosition: CameraLensPosition = .back
    var showSettingsSheet: Bool = false

    var rotationDirection: RotationGuideDirection = .upright
    var allCompleted: Bool = false

    var pendingPairCount: Int = 0
    var completedPairCount: Int = 0

    let events: AsyncStream<Event>

    let zoomDragState: AfterCameraZoomDragState = .init()

    private let captureAfter: CaptureAfterUseCase
    private let pairRepo: PhotoPairRepository
    private let storage: PhotoStoring
    private let appSettings: AppSettings
    private let captureSource: AfterCameraCaptureSource
    private let permissionProbe: @Sendable () async -> Bool
    private let eventsContinuation: AsyncStream<Event>.Continuation
    private(set) var supportedPresets: Set<ZoomPreset> = []
    private var allCompletedDismissTask: Task<Void, Never>?

    init(
        albumId: UUID?,
        initialPairId: UUID? = nil,
        retakeMode: Bool = false,
        captureAfter: CaptureAfterUseCase,
        pairRepo: PhotoPairRepository,
        storage: PhotoStoring,
        appSettings: AppSettings,
        session: CameraSession? = nil,
        captureSource: AfterCameraCaptureSource? = nil,
        permissionProbe: @escaping @Sendable () async -> Bool = AfterCameraPermissionProbe.resolve
    ) {
        self.albumId = albumId
        self.initialPairId = initialPairId
        self.retakeMode = retakeMode
        self.captureAfter = captureAfter
        self.pairRepo = pairRepo
        self.storage = storage
        self.appSettings = appSettings
        let resolvedSession = session ?? CameraSession()
        self.session = resolvedSession
        self.captureSource = captureSource ?? AfterCameraSessionCaptureSource(session: resolvedSession)
        self.permissionProbe = permissionProbe
        activePreset = .wide
        var continuation: AsyncStream<Event>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventsContinuation = continuation
    }

    var stripProgress: AfterCameraStripProgress? {
        guard !retakeMode else { return nil }
        let total = pendingPairCount + completedPairCount
        guard total > 0 else { return nil }
        return AfterCameraStripProgress(completed: completedPairCount, total: total)
    }

    nonisolated var captureSession: AVCaptureSession {
        session.captureSession
    }

    nonisolated func isPresetSupported(_ preset: ZoomPreset) -> Bool {
        MainActor.assumeIsolated { supportedPresets.contains(preset) }
    }

    func onAppear() async {
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)
        cameraPermissionGranted = await permissionProbe()
        guard cameraPermissionGranted == true else { return }
        await session.start()
        await refreshCapabilities()
        minZoom = await session.minZoomFactor
        maxZoom = await session.maxZoomFactor
        currentZoomRatio = await session.currentZoomFactor
        await loadPendingScopeAndStart()
    }

    func onDisappear() {
        allCompletedDismissTask?.cancel()
        allCompletedDismissTask = nil
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
        guard !retakeMode else { return }
        guard let newId else { return }
        guard newId != currentPair?.id else { return }
        guard let pair = pairs.first(where: { $0.id == newId }) else { return }
        adopt(pair: pair)
    }

    func onSettingsTap() {
        showSettingsSheet = true
    }

    func updateRotation(orientation: UIDeviceOrientation) {
        rotationDirection = RotationGuideResolver.direction(for: orientation)
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
            let prefix = FileNamePrefixValidator.sanitize(appSettings.fileNamePrefix)
            let updated = try await captureAfter(
                pairId: pair.id,
                afterJPEG: captured.jpegData,
                prefix: prefix,
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
        if retakeMode, let id = initialPairId {
            await loadRetakeTarget(id: id)
            return
        }
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

    private func loadRetakeTarget(id: UUID) async {
        guard let pair = try? await pairRepo.fetch(id: id) else {
            eventsContinuation.yield(.dismiss)
            return
        }
        pairs = [pair]
        pendingPairCount = 1
        completedPairCount = 0
        adopt(pair: pair)
    }

    private func advanceToNextOrFinish(after _: PhotoPair) async {
        if retakeMode {
            currentPair = nil
            ghostImageData = nil
            eventsContinuation.yield(.dismiss)
            return
        }
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
        let loaded = AfterCameraGhostLoader.loadData(beforeFileName: pair.beforeFileName, storage: storage)
        ghostImageData = loaded
        if loaded == nil {
            ghostWarningToast = String(
                localized: "Before 사진을 찾을 수 없어 overlay 없이 진행합니다."
            )
        }
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)
        hasRestoredZoom = false
        Task { await restoreZoom(for: pair) }
    }

    func refreshCapabilities() async {
        var supported: Set<ZoomPreset> = []
        for preset in ZoomPreset.allCases where await session.isPresetSupported(preset) {
            supported.insert(preset)
        }
        supportedPresets = supported
    }

    private func restoreZoom(for pair: PhotoPair) async {
        guard !hasRestoredZoom else { return }
        let target = pair.cameraSettings?.zoomFactor ?? 1.0
        await session.setZoomFactor(target)
        let actual = await session.currentZoomFactor
        pinchBaseFactor = actual
        currentZoomRatio = actual
        activePreset = AfterCameraZoomPresetMatcher.match(actual)
        hasRestoredZoom = true
    }

    private func refreshPairs() async {
        let snapshot = await AfterCameraScopeFetch(pairRepo: pairRepo, albumId: albumId).fetch()
        pairs = snapshot.pending
        pendingPairCount = snapshot.pending.count
        completedPairCount = snapshot.completedCount
    }

    static func captureErrorText(for error: Error) -> String {
        AfterCameraCaptureErrorMessages.text(for: error)
    }

    deinit {}
}

enum AfterCameraCaptureErrorMessages {
    static func text(for error: Error) -> String {
        if error is CameraSessionError {
            return String(localized: "카메라에서 사진을 가져올 수 없습니다. 다시 시도해 주세요.")
        }
        if let captureAfter = error as? CaptureAfterUseCase.CaptureAfterError {
            switch captureAfter {
                case .pairNotFound:
                    return String(localized: "사진 정보를 저장하지 못했습니다. 다시 시도해 주세요.")
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain || nsError.domain == NSPOSIXErrorDomain {
            return String(localized: "사진을 저장할 공간이 부족합니다.")
        }
        return String(localized: "촬영을 완료할 수 없습니다. 잠시 후 다시 시도해 주세요.")
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

enum AfterCameraGhostLoader {
    static func loadData(beforeFileName: String, storage: PhotoStoring) -> Data? {
        guard !beforeFileName.isEmpty else { return nil }
        guard let url = storage.resolveBefore(fileName: beforeFileName) else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }
}
