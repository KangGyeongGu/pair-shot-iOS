@preconcurrency import AVFoundation
import SwiftData
import SwiftUI
import UIKit

struct AfterCameraView: View {
    let albumId: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var appSettings

    @State private var sessionHolder = CameraSessionHolder()
    @State private var currentPair: PhotoPair?
    @State private var ghostImage: UIImage?
    @State private var cameraPermissionGranted: Bool?
    @State private var alpha: Double = GhostOverlayMath.defaultAlpha
    @State private var activePreset: ZoomPreset? = .wide
    @State private var isCapturing: Bool = false
    @State private var pinchBaseFactor: Double = 1.0
    @State private var hasRestoredZoom: Bool = false
    @State private var previewView: CameraPreviewView?
    @State private var captureErrorMessage: String?
    @State private var ghostWarningToast: String?

    private let storage = PhotoStorageService()

    init(albumId: UUID? = nil) {
        self.albumId = albumId
    }

    private var coordinator: AfterCaptureCoordinator {
        AfterCaptureCoordinator(
            session: sessionHolder.session,
            storage: storage,
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
                AfterCameraStack(
                    captureSession: sessionHolder.session.captureSession,
                    onMakePreviewView: { view in previewView = view },
                    ghostImage: ghostImage,
                    alpha: $alpha,
                    pendingCount: pendingPairCount,
                    completedCount: completedPairCount,
                    activePreset: activePreset,
                    isPresetSupported: sessionHolder.isPresetSupported(_:),
                    isCapturing: isCapturing,
                    canCapture: currentPair != nil,
                    pinchGesture: AnyGesture(pinchGesture.map { _ in () }),
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
            await onEnterScreen()
        }
        .onDisappear {
            Task { await sessionHolder.session.stop() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .captureErrorAlert(message: $captureErrorMessage)
        .ghostWarningToast(message: $ghostWarningToast)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard cameraPermissionGranted == true else { return }
        switch CameraScenePhaseGate.action(for: newPhase) {
            case .stop:
                Task { await sessionHolder.session.stop() }

            case .start:
                Task { await sessionHolder.session.start() }

            case nil:
                break
        }
    }

    private var scopedPairs: [PhotoPair] {
        let descriptor = FetchDescriptor<PhotoPair>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        guard let albumId else { return all }
        return all.filter { pair in
            pair.albums.contains(where: { $0.id == albumId })
        }
    }

    private var pendingPairCount: Int {
        AfterCameraPairLoader.pendingPairs(in: scopedPairs).count
    }

    private var completedPairCount: Int {
        scopedPairs.count(where: { $0.afterFileName != nil })
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let target = pinchBaseFactor * Double(value)
                Task { await sessionHolder.session.ramp(toZoomFactor: target, rate: 6.0) }
                activePreset = matchingPreset(for: target)
            }
            .onEnded { value in
                pinchBaseFactor *= Double(value)
            }
    }

    private func onEnterScreen() async {
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)

        await checkCameraPermission()
        guard cameraPermissionGranted == true else { return }

        await sessionHolder.session.start()
        await sessionHolder.refreshCapabilities()
        loadFirstPendingOrDismiss()
    }

    private func checkCameraPermission() async {
        cameraPermissionGranted = await Self.resolveCameraPermission()
    }

    private func loadFirstPendingOrDismiss() {
        guard let pair = AfterCameraPairLoader.firstPendingPair(in: scopedPairs) else {
            dismiss()
            return
        }
        adopt(pair: pair)
    }

    private func adopt(pair: PhotoPair) {
        currentPair = pair
        let loaded = GhostOverlayLoader.loadImage(beforeFileName: pair.beforeFileName, storage: storage)
        ghostImage = loaded
        if loaded == nil {
            ghostWarningToast = String(
                localized: "Before 사진을 찾을 수 없어 overlay 없이 진행합니다."
            )
        }
        alpha = GhostOverlayMath.clamp(appSettings.defaultOverlayAlpha)
        hasRestoredZoom = false
        Task { await restoreZoom(for: pair) }
    }

    private func restoreZoom(for pair: PhotoPair) async {
        guard !hasRestoredZoom else { return }
        let target = pair.cameraSettings?.zoomFactor ?? 1.0
        await sessionHolder.session.setZoomFactor(target)
        let actual = await sessionHolder.session.currentZoomFactor
        await MainActor.run {
            pinchBaseFactor = actual
            activePreset = matchingPreset(for: actual)
            hasRestoredZoom = true
        }
    }

    private func matchingPreset(for factor: Double) -> ZoomPreset? {
        let tolerance = 0.05
        return ZoomPreset.allCases.first { abs($0.factor - factor) <= tolerance }
    }

    private func applyPreset(_ preset: ZoomPreset) {
        activePreset = preset
        pinchBaseFactor = preset.factor
        Task { await sessionHolder.session.setZoomFactor(preset.factor) }
    }

    private func shutter() {
        guard !isCapturing, let pair = currentPair else { return }
        HapticService.shared.impact(.heavy)
        isCapturing = true
        Task {
            defer { isCapturing = false }
            do {
                let outcome = try await coordinator.captureAfter(
                    for: pair,
                    into: modelContext,
                    pendingScope: scopedPairs
                )
                CaptureHaptics.success()
                await MainActor.run {
                    if let next = outcome.nextPendingPair {
                        adopt(pair: next)
                    } else {
                        currentPair = nil
                        ghostImage = nil
                        dismiss()
                    }
                }
            } catch {
                captureErrorMessage = Self.afterCaptureErrorText(for: error)
            }
        }
    }
}
