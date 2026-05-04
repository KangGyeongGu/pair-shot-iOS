import SwiftData
import SwiftUI

struct BeforeCameraView: View {
    let albumId: UUID?
    let refillPairId: UUID?
    let onHome: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppEnvironment.self) private var env

    @State private var viewModel: BeforeCameraViewModel?
    @State private var didStartViewModel = false
    @State private var hasPresentedColdStartAppOpen = false
    @State private var didSubscribeMotion = false
    @State private var focusIndicator: FocusIndicatorState?
    @State private var previewView: CameraPreviewView?
    @State private var afterCameraTarget: AfterCameraTarget?
    @State private var showSettingsSheet = false

    init(
        albumId: UUID? = nil,
        refillPairId: UUID? = nil,
        onHome: (() -> Void)? = nil
    ) {
        self.albumId = albumId
        self.refillPairId = refillPairId
        self.onHome = onHome
    }

    var body: some View {
        ZStack {
            Color.appCameraBackground.ignoresSafeArea()

            if let viewModel {
                content(for: viewModel)
            }

            settingsOverlay
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .onAppear { ensureViewModelSync() }
        .task {
            ensureViewModelSync()
            guard let vm = viewModel else { return }
            if !didStartViewModel {
                didStartViewModel = true
                Task {
                    await vm.onAppear()
                    Task { @MainActor in
                        guard !hasPresentedColdStartAppOpen, vm.cameraPermissionGranted == true else {
                            return
                        }
                        hasPresentedColdStartAppOpen = true
                        await env.appOpenAdManager.presentIfReady(
                            from: BannerAdView.resolveRootViewController(),
                            coordinator: env.fullscreenAdCoordinator,
                            adFreeStore: env.adFreeStore
                        )
                    }
                }
            }
            await observeEvents(viewModel: vm)
        }
        .onDisappear {
            viewModel?.onDisappear()
            releaseMotionIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel?.handleScenePhaseAction(CameraScenePhaseGate.action(for: newPhase))
            if newPhase == .background { releaseMotionIfNeeded() }
            if newPhase == .active, viewModel?.isLevelOn == true { acquireMotionIfNeeded() }
        }
        .onChange(of: viewModel?.isLevelOn ?? false) { _, isOn in
            if isOn { acquireMotionIfNeeded() } else { releaseMotionIfNeeded() }
        }
        .fullScreenCover(item: $afterCameraTarget) { target in
            NavigationStack {
                AfterCameraView(
                    albumId: albumId,
                    initialPairId: target.pairId,
                    sortOrder: .newest
                )
            }
        }
        .captureErrorAlert(message: Binding(
            get: { viewModel?.captureErrorMessage },
            set: { viewModel?.captureErrorMessage = $0 }
        ))
    }

    @ViewBuilder
    private var settingsOverlay: some View {
        if showSettingsSheet, let viewModel {
            BeforeCameraSettingsOverlay(
                isPresented: $showSettingsSheet,
                isGridOn: viewModel.isGridOn,
                isLevelOn: viewModel.isLevelOn,
                isNightModeOn: viewModel.isNightModeOn,
                flashMode: viewModel.flashMode,
                onToggleGrid: viewModel.toggleGrid,
                onToggleLevel: viewModel.toggleLevel,
                onToggleNightMode: viewModel.toggleNightMode,
                onCycleFlash: viewModel.cycleFlash
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showSettingsSheet)
        }
    }

    @ViewBuilder
    private func content(for viewModel: BeforeCameraViewModel) -> some View {
        if viewModel.cameraPermissionGranted == false {
            PermissionDeniedView(forCamera: ())
                .padding(.horizontal, 32)
        } else {
            BeforeCameraStack(
                captureSession: viewModel.captureSession,
                onMakePreviewView: { view in
                    previewView = view
                    viewModel.session.attachPreviewLayer(view.previewLayer)
                },
                previewLayerProvider: { previewView?.previewLayer },
                isGridOn: viewModel.isGridOn,
                isLevelOn: viewModel.isLevelOn,
                isNightModeOn: viewModel.isNightModeOn,
                flashMode: viewModel.flashMode,
                rollDegrees: env.motionService.rollDegrees,
                presets: viewModel.availablePresets,
                displayMultiplier: viewModel.displayMultiplier,
                activePreset: viewModel.activePreset,
                isDraggingZoom: viewModel.isDraggingZoom,
                currentZoomRatio: viewModel.currentZoomRatio,
                minZoomRatio: viewModel.minZoom,
                maxZoomRatio: viewModel.maxZoom,
                exposureRangeProvider: { viewModel.cachedExposureRange },
                focusIndicator: $focusIndicator,
                isCapturing: viewModel.isCapturing,
                lastThumbnail: viewModel.lastThumbnail,
                pendingPairs: viewModel.pendingPairs,
                onTapFocus: viewModel.onTapFocus(devicePoint:),
                onExposureBias: viewModel.onExposureBias(_:),
                pinchGesture: AnyGesture(pinchGesture(for: viewModel).map { _ in () }),
                onApplyPreset: viewModel.applyPreset,
                onZoomDragChanged: viewModel.onZoomDragChanged(deltaPx:),
                onZoomDragEnded: viewModel.onZoomDragEnded,
                onShutter: { handleShutter(viewModel: viewModel) },
                onLeadingTap: handleLeadingTap,
                onToggleLens: viewModel.toggleLens,
                onToggleGrid: viewModel.toggleGrid,
                onToggleLevel: viewModel.toggleLevel,
                onToggleNightMode: viewModel.toggleNightMode,
                onCycleFlash: viewModel.cycleFlash,
                onSettingsTap: { showSettingsSheet = true }
            )
        }
    }

    private func pinchGesture(for viewModel: BeforeCameraViewModel) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in viewModel.onPinchChanged(Double(value)) }
            .onEnded { value in viewModel.onPinchEnded(Double(value)) }
    }

    private func handleShutter(viewModel: BeforeCameraViewModel) {
        env.hapticService.impact(.heavy)
        Task { await viewModel.shutter() }
    }

    private func handleLeadingTap() {
        if let onHome {
            onHome()
        } else {
            dismiss()
        }
    }

    private func ensureViewModelSync() {
        guard viewModel == nil else { return }
        viewModel = env.makeBeforeCameraViewModel(
            albumId: albumId,
            refillPairId: refillPairId
        )
    }

    private func acquireMotionIfNeeded() {
        guard !didSubscribeMotion else { return }
        env.motionService.start()
        didSubscribeMotion = true
    }

    private func releaseMotionIfNeeded() {
        guard didSubscribeMotion else { return }
        env.motionService.stop()
        didSubscribeMotion = false
    }

    private func observeEvents(viewModel: BeforeCameraViewModel) async {
        for await event in viewModel.events {
            switch event {
                case .dismiss:
                    dismiss()

                case .snackbarSuccess:
                    CaptureHaptics.success(env.hapticService)

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
