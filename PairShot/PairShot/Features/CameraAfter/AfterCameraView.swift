import SwiftData
import SwiftUI
import UIKit

struct AfterCameraView: View {
    let albumId: UUID?
    let initialPairId: UUID?
    let sortOrder: HomeSortOrder

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppEnvironment.self) private var env

    @State private var viewModel: AfterCameraViewModel?
    @State private var showSettingsSheet = false
    @State private var cachedGhostImage: UIImage?
    @State private var didStartViewModel = false

    init(
        albumId: UUID? = nil,
        initialPairId: UUID? = nil,
        sortOrder: HomeSortOrder = .newest
    ) {
        self.albumId = albumId
        self.initialPairId = initialPairId
        self.sortOrder = sortOrder
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
                Task { await vm.onAppear() }
            }
            await observeEvents(viewModel: vm)
        }
        .task {
            ensureViewModelSync()
            guard let vm = viewModel else { return }
            await observeOrientation(viewModel: vm)
        }
        .onDisappear { viewModel?.onDisappear() }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel?.handleScenePhaseAction(CameraScenePhaseGate.action(for: newPhase))
        }
        .onChange(of: viewModel?.ghostImageData) { _, newData in
            updateCachedGhostImage(from: newData)
        }
        .captureErrorAlert(message: Binding(
            get: { viewModel?.captureErrorMessage },
            set: { viewModel?.captureErrorMessage = $0 }
        ))
        .ghostWarningToast(message: Binding(
            get: { viewModel?.ghostWarningToast },
            set: { viewModel?.ghostWarningToast = $0 }
        ))
    }

    @ViewBuilder
    private var settingsOverlay: some View {
        if showSettingsSheet, let viewModel {
            AfterCameraSettingsOverlay(
                isPresented: $showSettingsSheet,
                isGridOn: viewModel.isGridOn,
                isLevelOn: viewModel.isLevelOn,
                isNightModeOn: viewModel.isNightModeOn,
                flashMode: viewModel.flashMode,
                overlayEnabled: viewModel.overlayEnabled,
                alpha: viewModel.alpha,
                onToggleGrid: viewModel.toggleGrid,
                onToggleLevel: viewModel.toggleLevel,
                onToggleNightMode: viewModel.toggleNightMode,
                onCycleFlash: viewModel.cycleFlash,
                onToggleOverlay: viewModel.toggleOverlay,
                onAlphaChange: viewModel.setAlpha
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showSettingsSheet)
        }
    }

    @ViewBuilder
    private func content(for viewModel: AfterCameraViewModel) -> some View {
        if viewModel.cameraPermissionGranted == false {
            PermissionDeniedView(forCamera: ())
                .padding(.horizontal, 32)
        } else {
            AfterCameraStack(
                captureSession: viewModel.captureSession,
                onMakePreviewView: { view in
                    viewModel.session.attachPreviewLayer(view.previewLayer)
                },
                ghostImage: cachedGhostImage,
                alpha: viewModel.alpha,
                overlayEnabled: viewModel.overlayEnabled,
                pairs: viewModel.pairs,
                selectedPairId: selectedPairIdBinding(for: viewModel),
                rotationDirection: viewModel.rotationDirection,
                isGridOn: viewModel.isGridOn,
                isLevelOn: viewModel.isLevelOn,
                isNightModeOn: viewModel.isNightModeOn,
                flashMode: viewModel.flashMode,
                presets: viewModel.availablePresets,
                displayMultiplier: viewModel.displayMultiplier,
                activePreset: viewModel.activePreset,
                isDraggingZoom: viewModel.isDraggingZoom,
                currentZoomRatio: viewModel.currentZoomRatio,
                minZoomRatio: viewModel.minZoom,
                maxZoomRatio: viewModel.maxZoom,
                isCapturing: viewModel.isCapturing,
                canCapture: viewModel.currentPair != nil,
                pinchGesture: AnyGesture(pinchGesture(for: viewModel).map { _ in () }),
                onApplyPreset: viewModel.applyPreset,
                onZoomDragChanged: viewModel.onZoomDragChanged(deltaPx:),
                onZoomDragEnded: viewModel.onZoomDragEnded,
                onShutter: { handleShutter(viewModel: viewModel) },
                onLeadingTap: { dismiss() },
                onToggleLens: viewModel.toggleLens,
                onToggleGrid: viewModel.toggleGrid,
                onToggleLevel: viewModel.toggleLevel,
                onToggleNightMode: viewModel.toggleNightMode,
                onCycleFlash: viewModel.cycleFlash,
                onToggleOverlay: viewModel.toggleOverlay,
                onAlphaChange: viewModel.setAlpha,
                onSettingsTap: { showSettingsSheet = true }
            )
        }
    }

    private func selectedPairIdBinding(for viewModel: AfterCameraViewModel) -> Binding<UUID?> {
        Binding(
            get: { viewModel.selectedPairId },
            set: { newValue in
                viewModel.selectedPairId = newValue
                viewModel.onSelectionChanged(newValue)
            }
        )
    }

    private func updateCachedGhostImage(from data: Data?) {
        guard let data else {
            cachedGhostImage = nil
            return
        }
        Task { @MainActor in
            let image = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)
            }.value
            cachedGhostImage = image
        }
    }

    private func pinchGesture(for viewModel: AfterCameraViewModel) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in viewModel.onPinchChanged(Double(value)) }
            .onEnded { value in viewModel.onPinchEnded(Double(value)) }
    }

    private func handleShutter(viewModel: AfterCameraViewModel) {
        env.hapticService.impact(.heavy)
        Task { await viewModel.shutter() }
    }

    private func ensureViewModelSync() {
        guard viewModel == nil else { return }
        viewModel = env.makeAfterCameraViewModel(
            albumId: albumId,
            initialPairId: initialPairId,
            sortOrder: sortOrder
        )
    }

    private func observeEvents(viewModel: AfterCameraViewModel) async {
        for await event in viewModel.events {
            switch event {
                case .dismiss:
                    dismiss()

                case .snackbarSuccess:
                    CaptureHaptics.success(env.hapticService)

                case .snackbarAllCompleted:
                    CaptureHaptics.success(env.hapticService)
                    env.snackbarQueue.enqueue(
                        "snackbar_success_all_after_captured",
                        variant: .success,
                        debounceKey: "all-after-captured"
                    )
            }
        }
    }

    private func observeOrientation(viewModel: AfterCameraViewModel) async {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        viewModel.updateRotation(orientation: UIDevice.current.orientation)
        let stream = NotificationCenter.default.notifications(named: UIDevice.orientationDidChangeNotification)
        for await _ in stream {
            viewModel.updateRotation(orientation: UIDevice.current.orientation)
        }
    }
}
