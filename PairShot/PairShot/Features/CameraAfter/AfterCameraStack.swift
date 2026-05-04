@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct AfterCameraStack: View {
    @Environment(AdFreeStore.self) private var adFreeStore

    let captureSession: AVCaptureSession
    let onMakePreviewView: (CameraPreviewView) -> Void

    let ghostImage: UIImage?
    let alpha: Double
    let overlayEnabled: Bool
    let ghostRotationDegrees: Double

    let pairs: [PhotoPair]
    let selectedPairId: Binding<UUID?>

    let rotationDirection: RotationGuideDirection

    let isGridOn: Bool
    let isLevelOn: Bool
    let isNightModeOn: Bool
    let flashMode: CameraFlashMode

    let presets: [ZoomPresetSpec]
    let displayMultiplier: Double
    let activePreset: ZoomPresetSpec?
    let isDraggingZoom: Bool
    let currentZoomRatio: Double
    let minZoomRatio: Double
    let maxZoomRatio: Double

    let isCapturing: Bool
    let canCapture: Bool

    let pinchGesture: AnyGesture<Void>
    let onApplyPreset: (ZoomPresetSpec) -> Void
    let onZoomDragChanged: (Double) -> Void
    let onZoomDragEnded: () -> Void
    let onShutter: () -> Void
    let onLeadingTap: () -> Void
    let onToggleLens: () -> Void
    let onToggleGrid: () -> Void
    let onToggleLevel: () -> Void
    let onToggleNightMode: () -> Void
    let onCycleFlash: () -> Void
    let onToggleOverlay: () -> Void
    let onAlphaChange: (Double) -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let layout = CameraLayoutMath.compute(
                totalSize: geo.size,
                isAdFree: adFreeStore.isAdFree
            )

            ZStack(alignment: .top) {
                Color.appCameraBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    previewArea(width: layout.previewWidth, height: layout.previewHeight)
                        .frame(width: layout.previewWidth, height: layout.previewHeight)
                        .background(Color.appCameraBackground)

                    AfterCameraStrip(
                        pairs: pairs,
                        selectedPairId: selectedPairId
                    )
                    .frame(height: layout.stripHeight)
                    .clipped()

                    CameraBottomBar(
                        lastThumbnail: nil,
                        isCapturing: isCapturing,
                        onLeadingTap: onLeadingTap,
                        onShutter: onShutter,
                        onSettingsTap: onSettingsTap
                    )
                    .opacity(canCapture ? 1.0 : 0.6)
                    .frame(height: layout.bottomBarHeight)
                    .clipped()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if !layout.isAdFree {
                    BannerAdSlot()
                        .frame(height: layout.bannerHeight)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func previewArea(width: CGFloat, height previewHeight: CGFloat) -> some View {
        ZStack {
            AfterCameraPreviewLayer(
                session: captureSession,
                onMakeView: onMakePreviewView
            )
            .clipped()

            GhostOverlayView(
                image: ghostImage,
                alpha: alpha,
                isEnabled: overlayEnabled,
                rotationDegrees: ghostRotationDegrees,
                width: width,
                height: previewHeight
            )

            if isGridOn {
                GridOverlay()
                    .allowsHitTesting(false)
            }

            Color.clear
                .contentShape(Rectangle())
                .gesture(pinchGesture)

            if rotationDirection != .upright {
                RotationGuideOverlay(direction: rotationDirection)
            }

            zoomBottomOverlay
        }
        .frame(width: width, height: previewHeight)
        .background(Color.appCameraBackground)
    }

    private var zoomBottomOverlay: some View {
        VStack {
            Spacer()
            ZStack(alignment: .trailing) {
                HStack {
                    Spacer()
                    ZoomControl(
                        presets: presets,
                        displayMultiplier: displayMultiplier,
                        activePreset: activePreset,
                        isDragging: isDraggingZoom,
                        currentRatio: currentZoomRatio,
                        minRatio: minZoomRatio,
                        maxRatio: maxZoomRatio,
                        onSelect: onApplyPreset,
                        onDragChanged: onZoomDragChanged,
                        onDragEnded: onZoomDragEnded
                    )
                    Spacer()
                }

                lensFlipButton
                    .opacity(isDraggingZoom ? 0 : 1)
                    .padding(.trailing, 12)
            }
            .padding(.bottom, 12)
        }
    }

    private var lensFlipButton: some View {
        Button(action: onToggleLens) {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "camera_desc_switch"))
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
