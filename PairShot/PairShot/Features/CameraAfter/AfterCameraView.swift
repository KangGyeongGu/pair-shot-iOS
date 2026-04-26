import SwiftData
import SwiftUI
import UIKit

struct AfterCameraView: View {
    let albumId: UUID?
    let initialPairId: UUID?
    let retakeMode: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppEnvironment.self) private var env

    @State private var viewModel: AfterCameraViewModel?

    init(
        albumId: UUID? = nil,
        initialPairId: UUID? = nil,
        retakeMode: Bool = false
    ) {
        self.albumId = albumId
        self.initialPairId = initialPairId
        self.retakeMode = retakeMode
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
        .task { await observeOrientation() }
        .onDisappear { viewModel?.onDisappear() }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel?.handleScenePhaseAction(CameraScenePhaseGate.action(for: newPhase))
        }
        .sheet(isPresented: settingsSheetBinding) {
            if let viewModel {
                AfterCameraSettingsSheet(viewModel: viewModel)
            }
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
    private func content(for viewModel: AfterCameraViewModel) -> some View {
        if viewModel.cameraPermissionGranted == false {
            PermissionDeniedView(forCamera: ())
                .padding(.horizontal, 32)
        } else {
            AfterCameraStack(
                captureSession: viewModel.captureSession,
                onMakePreviewView: { _ in },
                ghostImage: ghostImage(for: viewModel),
                alpha: viewModel.alpha,
                overlayEnabled: viewModel.overlayEnabled,
                pairs: viewModel.pairs,
                selectedPairId: selectedPairIdBinding(for: viewModel),
                storage: env.photoStorageService,
                stripProgress: viewModel.stripProgress,
                rotationDirection: viewModel.rotationDirection,
                activePreset: viewModel.activePreset,
                isPresetSupported: viewModel.isPresetSupported(_:),
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
                onSettingsTap: viewModel.onSettingsTap,
                onLeadingTap: { dismiss() },
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

    private func selectedPairIdBinding(for viewModel: AfterCameraViewModel) -> Binding<UUID?> {
        Binding(
            get: { viewModel.selectedPairId },
            set: { newValue in
                viewModel.selectedPairId = newValue
                viewModel.onSelectionChanged(newValue)
            }
        )
    }

    private func ghostImage(for viewModel: AfterCameraViewModel) -> UIImage? {
        guard let data = viewModel.ghostImageData else { return nil }
        return UIImage(data: data)
    }

    private func pinchGesture(for viewModel: AfterCameraViewModel) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in viewModel.onPinchChanged(Double(value)) }
            .onEnded { value in viewModel.onPinchEnded(Double(value)) }
    }

    private func handleShutter(viewModel: AfterCameraViewModel) {
        HapticService.shared.impact(.heavy)
        Task { await viewModel.shutter() }
    }

    private func ensureViewModel() async {
        if viewModel == nil {
            viewModel = env.makeAfterCameraViewModel(
                albumId: albumId,
                initialPairId: initialPairId,
                retakeMode: retakeMode
            )
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

                case .snackbarAllCompleted:
                    CaptureHaptics.success()
            }
        }
    }

    private func observeOrientation() async {
        while viewModel == nil {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let viewModel else { return }
        await MainActor.run {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            viewModel.updateRotation(orientation: UIDevice.current.orientation)
        }
        let stream = NotificationCenter.default.notifications(named: UIDevice.orientationDidChangeNotification)
        for await _ in stream {
            await MainActor.run {
                viewModel.updateRotation(orientation: UIDevice.current.orientation)
            }
        }
    }
}
