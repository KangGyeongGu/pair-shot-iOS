@preconcurrency import AVFoundation
import SwiftData
import SwiftUI

/// Top-level Before-capture screen. Hosts the preview layer, all overlays
/// (focus reticle, grid, level), and the control bars.
///
/// Integration into `ArchiveView` happens in a later phase; this file only
/// provides the screen itself so each sub-feature can be exercised in
/// isolation (and inside `#Preview`).
struct BeforeCameraView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
                cameraStack
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
    }

    /// Live-camera content. Extracted so the permission-denied
    /// fallback short-circuits before we spin up the AVFoundation
    /// session.
    private var cameraStack: some View {
        ZStack {
            BeforeCameraPreviewLayer(
                session: sessionHolder.session.captureSession,
                onMakeView: { view in previewView = view }
            )
            .ignoresSafeArea()

            if isGridOn {
                GridOverlay()
                    .ignoresSafeArea()
            }

            FocusGestureView(
                previewLayerProvider: { previewView?.previewLayer },
                onTapFocus: { devicePoint in
                    Task { await sessionHolder.session.focus(at: devicePoint) }
                },
                onExposureBias: { bias in
                    Task { await sessionHolder.session.setExposureBias(bias) }
                },
                exposureRangeProvider: { sessionHolder.cachedExposureRange },
                indicator: $focusIndicator
            )
            .ignoresSafeArea()
            .gesture(pinchGesture)

            if let focusIndicator {
                FocusReticleView(state: focusIndicator)
            }

            VStack {
                CameraControlBar(
                    flashMode: flashMode,
                    lensPosition: lensPosition,
                    isGridOn: isGridOn,
                    isLevelOn: isLevelOn,
                    onCycleFlash: cycleFlash,
                    onToggleLens: toggleLens,
                    onToggleGrid: { isGridOn.toggle() },
                    onToggleLevel: toggleLevel
                )

                if isLevelOn {
                    LevelIndicator(rollDegrees: motion.rollDegrees)
                        .padding(.top, 4)
                }

                Spacer()

                ZoomControl(
                    activePreset: activePreset,
                    isSupported: sessionHolder.isPresetSupported(_:),
                    onSelect: applyPreset
                )
                .padding(.bottom, 12)

                HStack(alignment: .center) {
                    ThumbnailWell(image: capturedThumbnail)
                        .padding(.leading, 24)

                    Spacer()

                    CaptureShutterButton(isCapturing: isCapturing, action: shutter)

                    Spacer()

                    Color.clear.frame(width: 56, height: 56).padding(.trailing, 24)
                }
                .padding(.bottom, 16)
            }
        }
    }

    /// Probe AVFoundation authorization. We don't request access here
    /// (that happens implicitly when the user opens this screen the
    /// very first time, via system prompt) — we only branch on the
    /// already-decided state. `notDetermined` flips through a request
    /// so the modal flow stays linear instead of bouncing the user
    /// out to Settings on first launch.
    private func checkCameraPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                cameraPermissionGranted = true

            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                cameraPermissionGranted = granted

            case .denied, .restricted:
                cameraPermissionGranted = false

            @unknown default:
                cameraPermissionGranted = false
        }
    }

    // MARK: - Gestures

    @State private var pinchBaseFactor: Double = 1.0

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
        isCapturing = true
        Task {
            defer { isCapturing = false }
            do {
                _ = try await coordinator.captureBefore(project: project, into: modelContext)
                CaptureHaptics.success()
            } catch {
                // P9.4 will own user-visible error UI; for now fail silently.
            }
        }
    }
}

/// Holds the actor + cached, view-side capability snapshots so the SwiftUI
/// gesture closures can read them synchronously without `await`.
@MainActor
@Observable
final class CameraSessionHolder {
    let session: CameraSession
    var cachedExposureRange: ClosedRange<Float>?
    private var supportedPresets: Set<ZoomPreset> = []

    init() {
        session = CameraSession()
    }

    func refreshCapabilities() async {
        cachedExposureRange = await session.exposureBiasRange

        var supported: Set<ZoomPreset> = []
        for preset in ZoomPreset.allCases {
            if await session.isPresetSupported(preset) {
                supported.insert(preset)
            }
        }
        supportedPresets = supported
    }

    nonisolated func isPresetSupported(_ preset: ZoomPreset) -> Bool {
        // SwiftUI calls this from view body — read the cached snapshot.
        // Captured via MainActor.assumeIsolated to satisfy strict concurrency.
        MainActor.assumeIsolated { supportedPresets.contains(preset) }
    }
}

/// Small wrapper around `CameraPreview` that reports the underlying UIView
/// up to the parent so it can be used for tap-to-device-point conversion.
private struct BeforeCameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession
    let onMakeView: (CameraPreviewView) -> Void

    func makeUIView(context _: Context) -> CameraPreviewView {
        let view = CameraPreviewView(session: session)
        Task { @MainActor in onMakeView(view) }
        return view
    }

    func updateUIView(_: CameraPreviewView, context _: Context) {}
}

/// Last-captured thumbnail. Round corner placeholder when nil.
private struct ThumbnailWell: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: 48, height: 48)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
