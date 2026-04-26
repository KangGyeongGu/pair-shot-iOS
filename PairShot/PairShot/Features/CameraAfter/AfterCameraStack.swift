@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct AfterCameraStack: View {
    let captureSession: AVCaptureSession
    let onMakePreviewView: (CameraPreviewView) -> Void

    let ghostImage: UIImage?
    let alpha: Double
    let overlayEnabled: Bool

    let pairs: [PhotoPair]
    let selectedPairId: Binding<UUID?>
    let storage: PhotoStorageService
    let stripProgress: AfterCameraStripProgress?

    let rotationDirection: RotationGuideDirection

    let activePreset: ZoomPreset?
    let isPresetSupported: (ZoomPreset) -> Bool
    let isDraggingZoom: Bool
    let currentZoomRatio: Double
    let minZoomRatio: Double
    let maxZoomRatio: Double

    let isCapturing: Bool
    let canCapture: Bool

    let pinchGesture: AnyGesture<Void>
    let onApplyPreset: (ZoomPreset) -> Void
    let onZoomDragChanged: (Double) -> Void
    let onZoomDragEnded: () -> Void
    let onShutter: () -> Void
    let onSettingsTap: () -> Void
    let onLeadingTap: () -> Void
    let onToggleLens: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            BannerAdSlot()

            previewArea

            AfterCameraStrip(
                pairs: pairs,
                selectedPairId: selectedPairId,
                storage: storage,
                progress: stripProgress
            )

            CameraBottomBar(
                lastThumbnail: nil,
                isCapturing: isCapturing,
                canShowHomeIcon: true,
                onLeadingTap: onLeadingTap,
                onShutter: onShutter,
                onSettingsTap: onSettingsTap
            )
            .opacity(canCapture ? 1.0 : 0.6)

            Spacer(minLength: 0)
                .frame(height: 32)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var previewArea: some View {
        ZStack {
            AfterCameraPreviewLayer(
                session: captureSession,
                onMakeView: onMakePreviewView
            )
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipped()

            GhostOverlayView(image: ghostImage, alpha: alpha, isEnabled: overlayEnabled)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)

            Color.clear
                .contentShape(Rectangle())
                .gesture(pinchGesture)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)

            if rotationDirection != .upright {
                RotationGuideOverlay(direction: rotationDirection)
            }

            VStack {
                Spacer()
                HStack(alignment: .center, spacing: 8) {
                    Spacer(minLength: 0)
                    ZoomControl(
                        activePreset: activePreset,
                        isSupported: isPresetSupported,
                        isDragging: isDraggingZoom,
                        currentRatio: currentZoomRatio,
                        minRatio: minZoomRatio,
                        maxRatio: maxZoomRatio,
                        onSelect: onApplyPreset,
                        onDragChanged: onZoomDragChanged,
                        onDragEnded: onZoomDragEnded
                    )
                    Spacer(minLength: 0)
                    lensFlipButton
                        .opacity(isDraggingZoom ? 0 : 1)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private var lensFlipButton: some View {
        Button(action: onToggleLens) {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .accessibilityLabel(String(localized: "전후면 전환"))
        }
        .buttonStyle(.plain)
    }
}

struct AfterCameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession
    let onMakeView: (CameraPreviewView) -> Void

    func makeUIView(context _: Context) -> CameraPreviewView {
        let view = CameraPreviewView(session: session)
        Task { @MainActor in onMakeView(view) }
        return view
    }

    func updateUIView(_: CameraPreviewView, context _: Context) {}
}
