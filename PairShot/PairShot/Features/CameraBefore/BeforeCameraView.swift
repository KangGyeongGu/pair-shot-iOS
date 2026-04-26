@preconcurrency import AVFoundation
import SwiftData
import SwiftUI

struct BeforeCameraView: View {
    let albumId: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var appSettings

    @State private var sessionHolder = CameraSessionHolder()
    @State private var motion = MotionService()
    @State private var lensPosition: CameraLensPosition = .back
    @State private var flashMode: CameraFlashMode = .off
    @State private var activePreset: ZoomPreset? = .wide
    @State private var minZoom: Double = 1
    @State private var maxZoom: Double = 1
    @State private var isGridOn: Bool = false
    @State private var isLevelOn: Bool = false
    @State private var focusIndicator: FocusIndicatorState?
    @State private var isCapturing: Bool = false
    @State private var capturedThumbnail: UIImage?
    @State private var cameraPermissionGranted: Bool?
    @State private var pinchBaseFactor: Double = 1.0
    @State private var captureErrorMessage: String?

    @State private var previewView: CameraPreviewView?

    init(albumId: UUID? = nil) {
        self.albumId = albumId
    }

    private var coordinator: BeforeCaptureCoordinator {
        BeforeCaptureCoordinator(
            session: sessionHolder.session,
            storage: PhotoStorageService(),
            fileNamePrefix: FileNamePrefixValidator.sanitize(appSettings.fileNamePrefix)
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraPermissionGranted == false {
                PermissionDeniedView(forCamera: ())
                    .padding(.horizontal, 32)
            } else {
                BeforeCameraStack(
                    captureSession: sessionHolder.session.captureSession,
                    onMakePreviewView: { view in previewView = view },
                    previewLayerProvider: { previewView?.previewLayer },
                    isGridOn: isGridOn,
                    isLevelOn: isLevelOn,
                    rollDegrees: motion.rollDegrees,
                    flashMode: flashMode,
                    lensPosition: lensPosition,
                    activePreset: activePreset,
                    isPresetSupported: sessionHolder.isPresetSupported(_:),
                    exposureRangeProvider: { sessionHolder.cachedExposureRange },
                    focusIndicator: $focusIndicator,
                    isCapturing: isCapturing,
                    capturedThumbnail: capturedThumbnail,
                    onTapFocus: { devicePoint in
                        Task { await sessionHolder.session.focus(at: devicePoint) }
                    },
                    onExposureBias: { bias in
                        Task { await sessionHolder.session.setExposureBias(bias) }
                    },
                    pinchGesture: AnyGesture(pinchGesture.map { _ in () }),
                    onCycleFlash: cycleFlash,
                    onToggleLens: toggleLens,
                    onToggleGrid: { isGridOn.toggle() },
                    onToggleLevel: toggleLevel,
                    onApplyPreset: applyPreset,
                    onShutter: shutter
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "닫기")) { dismiss() }
                    .tint(.white)
            }
        }
        .task {
            await checkCameraPermission()
            guard cameraPermissionGranted == true else { return }
            await sessionHolder.session.start()
            await sessionHolder.refreshCapabilities()
            minZoom = await sessionHolder.session.minZoomFactor
            maxZoom = await sessionHolder.session.maxZoomFactor
        }
        .onDisappear {
            Task { await sessionHolder.session.stop() }
            motion.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .captureErrorAlert(message: $captureErrorMessage)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard cameraPermissionGranted == true else { return }
        switch CameraScenePhaseGate.action(for: newPhase) {
            case .stop:
                Task { await sessionHolder.session.stop() }
                motion.stop()

            case .start:
                Task { await sessionHolder.session.start() }
                if isLevelOn { motion.start() }

            case nil:
                break
        }
    }

    private func checkCameraPermission() async {
        cameraPermissionGranted = await Self.resolveCameraPermission()
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let target = pinchBaseFactor * Double(value)
                Task {
                    await sessionHolder.session.ramp(toZoomFactor: target, rate: 6.0)
                }
                activePreset = matchingPreset(for: target)
            }
            .onEnded { value in
                pinchBaseFactor *= Double(value)
            }
    }

    private func matchingPreset(for factor: Double) -> ZoomPreset? {
        let tolerance = 0.05
        return ZoomPreset.allCases.first { abs($0.factor - factor) <= tolerance }
    }

    private func cycleFlash() {
        Task {
            let next = await sessionHolder.session.cycleFlashMode()
            flashMode = next
        }
    }

    private func toggleLens() {
        let next: CameraLensPosition = lensPosition == .back ? .front : .back
        Task {
            await sessionHolder.session.switchLens(to: next)
            await sessionHolder.refreshCapabilities()
            lensPosition = next
            minZoom = await sessionHolder.session.minZoomFactor
            maxZoom = await sessionHolder.session.maxZoomFactor
            pinchBaseFactor = await sessionHolder.session.currentZoomFactor
            activePreset = matchingPreset(for: pinchBaseFactor) ?? .wide
        }
    }

    private func toggleLevel() {
        isLevelOn.toggle()
        if isLevelOn { motion.start() } else { motion.stop() }
    }

    private func applyPreset(_ preset: ZoomPreset) {
        activePreset = preset
        pinchBaseFactor = preset.factor
        Task { await sessionHolder.session.setZoomFactor(preset.factor) }
    }

    private func shutter() {
        guard !isCapturing else { return }
        HapticService.shared.impact(.heavy)
        isCapturing = true
        Task {
            defer { isCapturing = false }
            do {
                _ = try await coordinator.captureBefore(
                    albumId: albumId,
                    into: modelContext
                )
                CaptureHaptics.success()
            } catch {
                captureErrorMessage = Self.captureErrorText(for: error)
            }
        }
    }
}
