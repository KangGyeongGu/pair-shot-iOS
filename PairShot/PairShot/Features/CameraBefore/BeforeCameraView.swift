import SwiftData
import SwiftUI

struct BeforeCameraView: View {
    let albumId: UUID?
    let refillPairId: UUID?
    let onHome: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppEnvironment.self) private var env
    @Environment(PromotionStore.self) private var promotionStore
    @Environment(SubscriptionStore.self) private var subscriptionStore

    @State private var viewModel: BeforeCameraViewModel?
    @State private var didSubscribeMotion = false
    @State private var focusIndicator: FocusIndicatorState?
    @State private var previewView: CameraPreviewView?
    @State private var afterCameraTarget: AfterCameraTarget?
    @State private var showSettingsSheet = false

    var body: some View {
        ZStack {
            Color.appCameraBackground.ignoresSafeArea()

            if let viewModel {
                content(for: viewModel)
            }

            settingsOverlay
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .onAppear { ensureViewModelSync() }
        .task {
            ensureViewModelSync()
            guard let vm = viewModel else { return }
            Task {
                await vm.onAppear()
                Task { @MainActor in
                    guard vm.cameraPermissionState == .granted else { return }
                    await env.promotionStore.refresh()
                    await env.appOpenAdManager.presentColdStartIfReady(
                        from: BannerAdView.resolveRootViewController(),
                        coordinator: env.fullscreenAdCoordinator,
                        promotionStore: promotionStore,
                        subscriptionStore: subscriptionStore,
                    )
                }
            }
            await observeEvents(viewModel: vm)
        }
        .onDisappear {
            viewModel?.onDisappear()
            releaseMotionIfNeeded()
        }
        .modifier(BeforeCameraMotionSubscription(
            scenePhase: scenePhase,
            isLevelOn: viewModel?.isLevelOn ?? false,
            isTutorialActive: env.tutorialCoordinator.isActive,
            onSync: syncMotionSubscription,
            onBackground: releaseMotionIfNeeded,
        ))
        .fullScreenCover(item: $afterCameraTarget) { target in
            NavigationStack {
                AfterCameraView(
                    albumId: albumId,
                    initialPairId: target.pairId,
                    sortOrder: .newest,
                )
            }
            .environment(env)
            .environment(env.tutorialCoordinator)
            .environment(\.tutorialMode, env.tutorialCoordinator.mode)
        }
        .captureErrorAlert(
            message: Binding(
                get: { viewModel?.captureErrorMessage },
                set: { viewModel?.captureErrorMessage = $0 },
            ),
        )
        .paywallSheet(
            isPresented: Binding(
                get: { viewModel?.showPaywall ?? false },
                set: { newValue in viewModel?.showPaywall = newValue },
            ),
        )
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
                aspect: viewModel.currentAspect,
                onToggleGrid: viewModel.toggleGrid,
                onToggleLevel: viewModel.toggleLevel,
                onToggleNightMode: viewModel.toggleNightMode,
                onCycleFlash: viewModel.cycleFlash,
                onCycleAspect: viewModel.cycleAspect,
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showSettingsSheet)
        }
    }

    init(
        albumId: UUID? = nil,
        refillPairId: UUID? = nil,
        onHome: (() -> Void)? = nil,
    ) {
        self.albumId = albumId
        self.refillPairId = refillPairId
        self.onHome = onHome
    }

    @ViewBuilder
    private func content(for viewModel: BeforeCameraViewModel) -> some View {
        if viewModel.cameraPermissionState == .denied {
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
                aspect: viewModel.currentAspect,
                isGridOn: viewModel.isGridOn,
                isLevelOn: viewModel.isLevelOn,
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
                pendingPairs: viewModel.pendingPairs,
                activePairId: viewModel.selectedPairId,
                onTapFocus: viewModel.onTapFocus(devicePoint:),
                onExposureBias: viewModel.onExposureBias(_:),
                pinchGesture: AnyGesture(pinchGesture(for: viewModel).map { _ in () }),
                onApplyPreset: viewModel.applyPreset,
                onZoomDragChanged: viewModel.onZoomDragChanged(deltaPx:),
                onZoomDragEnded: viewModel.onZoomDragEnded,
                onShutter: { handleShutter(viewModel: viewModel) },
                onLeadingTap: handleLeadingTap,
                onToggleLens: viewModel.toggleLens,
                onSettingsTap: { showSettingsSheet = true },
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
        let roll = env.motionService.rollDegrees
        Task { await viewModel.shutter(rollDegrees: roll) }
    }

    private func handleLeadingTap() {
        advanceTutorialOnHomeTap()
        if let onHome {
            onHome()
        } else {
            dismiss()
        }
    }

    private func advanceTutorialOnHomeTap() {
        let coord = env.tutorialCoordinator
        guard coord.isAtStep(.backToHome) else { return }
        coord.advance()
    }

    private func ensureViewModelSync() {
        guard viewModel == nil else { return }
        viewModel = env.makeBeforeCameraViewModel(
            albumId: albumId,
            refillPairId: refillPairId,
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

    private func syncMotionSubscription() {
        let shouldKeep = viewModel?.isLevelOn == true || env.tutorialCoordinator.isActive
        if shouldKeep {
            acquireMotionIfNeeded()
        } else {
            releaseMotionIfNeeded()
        }
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

private struct BeforeCameraMotionSubscription: ViewModifier {
    let scenePhase: ScenePhase
    let isLevelOn: Bool
    let isTutorialActive: Bool
    let onSync: () -> Void
    let onBackground: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    onBackground()
                } else if newPhase == .active {
                    onSync()
                }
            }
            .onChange(of: isLevelOn) { _, _ in onSync() }
            .onChange(of: isTutorialActive) { _, _ in onSync() }
            .task { onSync() }
    }
}

struct AfterCameraTarget: Identifiable, Hashable {
    let pairId: UUID

    var id: UUID {
        pairId
    }
}
