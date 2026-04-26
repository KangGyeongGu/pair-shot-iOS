@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct BeforeCameraStack: View {
    let captureSession: AVCaptureSession
    let onMakePreviewView: (CameraPreviewView) -> Void
    let previewLayerProvider: () -> AVCaptureVideoPreviewLayer?

    let isGridOn: Bool
    let isLevelOn: Bool
    let rollDegrees: Double

    let activePreset: ZoomPreset?
    let isPresetSupported: (ZoomPreset) -> Bool
    let isDraggingZoom: Bool
    let currentZoomRatio: Double
    let minZoomRatio: Double
    let maxZoomRatio: Double
    let exposureRangeProvider: () -> ClosedRange<Float>?
    let focusIndicator: Binding<FocusIndicatorState?>

    let isCapturing: Bool
    let lastThumbnail: UIImage?
    let canShowHomeIcon: Bool

    let pendingPairs: [PhotoPair]
    let storage: PhotoStorageService

    let onTapFocus: (CGPoint) -> Void
    let onExposureBias: (Float) -> Void
    let pinchGesture: AnyGesture<Void>

    let onApplyPreset: (ZoomPreset) -> Void
    let onZoomDragChanged: (Double) -> Void
    let onZoomDragEnded: () -> Void
    let onShutter: () -> Void
    let onSettingsTap: () -> Void
    let onLeadingTap: () -> Void
    let onStripPairTap: (PhotoPair) -> Void
    let onToggleLens: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            BannerAdSlot()

            previewArea

            BeforeCameraStrip(
                pendingPairs: pendingPairs,
                storage: storage,
                onTapPair: onStripPairTap
            )

            CameraBottomBar(
                lastThumbnail: lastThumbnail,
                isCapturing: isCapturing,
                canShowHomeIcon: canShowHomeIcon,
                onLeadingTap: onLeadingTap,
                onShutter: onShutter,
                onSettingsTap: onSettingsTap
            )

            Spacer(minLength: 0)
                .frame(height: 32)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var previewArea: some View {
        ZStack {
            BeforeCameraPreviewLayer(
                session: captureSession,
                onMakeView: onMakePreviewView
            )
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipped()

            if isGridOn {
                GridOverlay()
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .allowsHitTesting(false)
            }

            FocusGestureView(
                previewLayerProvider: previewLayerProvider,
                onTapFocus: onTapFocus,
                onExposureBias: onExposureBias,
                exposureRangeProvider: exposureRangeProvider,
                indicator: focusIndicator
            )
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .gesture(pinchGesture)

            if let indicator = focusIndicator.wrappedValue {
                FocusReticleView(state: indicator)
            }

            if isLevelOn {
                VStack {
                    LevelIndicator(rollDegrees: rollDegrees)
                        .padding(.top, 12)
                    Spacer()
                }
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

struct BeforeCameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession
    let onMakeView: (CameraPreviewView) -> Void

    func makeUIView(context _: Context) -> CameraPreviewView {
        let view = CameraPreviewView(session: session)
        Task { @MainActor in onMakeView(view) }
        return view
    }

    func updateUIView(_: CameraPreviewView, context _: Context) {}
}
