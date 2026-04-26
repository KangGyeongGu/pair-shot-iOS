@preconcurrency import AVFoundation
import SwiftData
import SwiftUI

/// Top-level Before-capture screen. Hosts the preview layer, all overlays
/// (focus reticle, grid, level), and the control bars. The actual camera
/// composite is in ``BeforeCameraStack`` (extracted in P10b so this view
/// stays under the 250-line cap).
struct BeforeCameraView: View {
    let project: Project

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
    /// P9.4 — `nil` until the first authorization probe completes.
    /// `false` on `.denied` / `.restricted` shows the
    /// `PermissionDeniedView` Settings deep-link instead of starting
    /// the session (which would just hang on a black preview).
    @State private var cameraPermissionGranted: Bool?
    @State private var pinchBaseFactor: Double = 1.0
    /// Audit-C — surface capture errors to the user instead of swallowing
    /// them silently. Setting this to a non-nil value drives the alert
    /// below; the user can dismiss to retry the shutter.
    @State private var captureErrorMessage: String?

    /// Stable reference to the preview UIView so taps can convert to device space.
    @State private var previewView: CameraPreviewView?

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
        // Audit-B — release the AVCaptureSession when the app is sent
        // to the background so it doesn't keep the camera lit / drain
        // battery while the user is elsewhere. Re-start when the app
        // returns to .active. The view's own .task handles the
        // very first start-up so we deliberately skip it here.
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        // Audit-C — capture failures surface as a dismissible alert
        // (extension `BeforeCameraView+CaptureError.swift`). Previously
        // the catch block ate the error, leaving the user staring at an
        // unresponsive shutter.
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

    /// Probe AVFoundation authorization. We don't request access here
    /// (that happens implicitly when the user opens this screen the
    /// very first time, via system prompt) — we only branch on the
    /// already-decided state. `notDetermined` flips through a request
    /// so the modal flow stays linear instead of bouncing the user
    /// out to Settings on first launch.
    private func checkCameraPermission() async {
        cameraPermissionGranted = await Self.resolveCameraPermission()
    }

    // MARK: - Gestures

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

    // MARK: - Actions

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
        // Audit-C — single `.heavy` impact on press. Coordinator no
        // longer fires its own shutter haptic so we won't double-tap.
        HapticService.shared.impact(.heavy)
        isCapturing = true
        Task {
            defer { isCapturing = false }
            do {
                _ = try await coordinator.captureBefore(project: project, into: modelContext)
                // Single `.success` notification once the JPEG is written
                // and the SwiftData row is inserted.
                CaptureHaptics.success()
            } catch {
                captureErrorMessage = Self.captureErrorText(for: error)
            }
        }
    }
}

// CameraSessionHolder lives in `CameraSessionHolder.swift` (Audit-B
// extraction) so this file stays under the 250-line view cap.
