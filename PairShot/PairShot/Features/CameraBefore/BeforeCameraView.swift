import SwiftData
import SwiftUI

struct BeforeCameraView: View {
    let albumId: UUID?
    let onHome: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppEnvironment.self) private var env

    @State private var viewModel: BeforeCameraViewModel?
    @State private var motion = MotionService()
    @State private var focusIndicator: FocusIndicatorState?
    @State private var previewView: CameraPreviewView?
    @State private var afterCameraTarget: AfterCameraTarget?

    init(albumId: UUID? = nil, onHome: (() -> Void)? = nil) {
        self.albumId = albumId
        self.onHome = onHome
    }

    var body: some View {
        ZStack {
            Color.appCameraBackground.ignoresSafeArea()

            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView().tint(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .task { await ensureViewModel() }
        .task { await observeEvents() }
        .onDisappear {
            viewModel?.onDisappear()
            motion.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel?.handleScenePhaseAction(CameraScenePhaseGate.action(for: newPhase))
            if newPhase == .background { motion.stop() }
            if newPhase == .active, viewModel?.isLevelOn == true { motion.start() }
        }
        .onChange(of: viewModel?.isLevelOn ?? false) { _, isOn in
            if isOn { motion.start() } else { motion.stop() }
        }
        .sheet(isPresented: settingsSheetBinding) {
            if let viewModel {
                CameraSettingsSheet(viewModel: viewModel)
            }
        }
        .fullScreenCover(item: $afterCameraTarget) { target in
            NavigationStack {
                AfterCameraView(albumId: albumId, initialPairId: target.pairId)
            }
        }
        .captureErrorAlert(message: Binding(
            get: { viewModel?.captureErrorMessage },
            set: { viewModel?.captureErrorMessage = $0 }
        ))
    }

    @ViewBuilder
    private func content(for viewModel: BeforeCameraViewModel) -> some View {
        if viewModel.cameraPermissionGranted == false {
            PermissionDeniedView(forCamera: ())
                .padding(.horizontal, 32)
        } else {
            BeforeCameraStack(
                captureSession: viewModel.captureSession,
                onMakePreviewView: { view in previewView = view },
                previewLayerProvider: { previewView?.previewLayer },
                isGridOn: viewModel.isGridOn,
                isLevelOn: viewModel.isLevelOn,
                rollDegrees: motion.rollDegrees,
                activePreset: viewModel.activePreset,
                isPresetSupported: viewModel.isPresetSupported(_:),
                isDraggingZoom: viewModel.isDraggingZoom,
                currentZoomRatio: viewModel.currentZoomRatio,
                minZoomRatio: viewModel.minZoom,
                maxZoomRatio: viewModel.maxZoom,
                exposureRangeProvider: { viewModel.cachedExposureRange },
                focusIndicator: $focusIndicator,
                isCapturing: viewModel.isCapturing,
                lastThumbnail: viewModel.lastThumbnail,
                canShowHomeIcon: onHome != nil,
                pendingPairs: viewModel.pendingPairs,
                storage: env.photoStorageService,
                onTapFocus: viewModel.onTapFocus(devicePoint:),
                onExposureBias: viewModel.onExposureBias(_:),
                pinchGesture: AnyGesture(pinchGesture(for: viewModel).map { _ in () }),
                onApplyPreset: viewModel.applyPreset,
                onZoomDragChanged: viewModel.onZoomDragChanged(deltaPx:),
                onZoomDragEnded: viewModel.onZoomDragEnded,
                onShutter: { handleShutter(viewModel: viewModel) },
                onSettingsTap: viewModel.onSettingsTap,
                onLeadingTap: handleLeadingTap,
                onStripPairTap: viewModel.onStripPairTap,
                onToggleLens: viewModel.toggleLens
            )
        }
    }

    private var settingsSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showSettingsSheet ?? false },
            set: { viewModel?.showSettingsSheet = $0 }
        )
    }

    private func pinchGesture(for viewModel: BeforeCameraViewModel) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in viewModel.onPinchChanged(Double(value)) }
            .onEnded { value in viewModel.onPinchEnded(Double(value)) }
    }

    private func handleShutter(viewModel: BeforeCameraViewModel) {
        HapticService.shared.impact(.heavy)
        Task { await viewModel.shutter() }
    }

    private func handleLeadingTap() {
        if let onHome {
            onHome()
        } else {
            dismiss()
        }
    }

    private func ensureViewModel() async {
        if viewModel == nil {
            viewModel = env.makeBeforeCameraViewModel(albumId: albumId)
        }
        await viewModel?.onAppear()
    }

    private func observeEvents() async {
        while viewModel == nil {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let viewModel else { return }
        for await event in viewModel.events {
            switch event {
                case .dismiss:
                    dismiss()

                case .snackbarSuccess:
                    CaptureHaptics.success()

                case let .openAfterCamera(pairId):
                    afterCameraTarget = AfterCameraTarget(pairId: pairId)
            }
        }
    }
}

struct AfterCameraTarget: Identifiable, Hashable {
    let pairId: UUID

    var id: UUID {
        pairId
    }
}
