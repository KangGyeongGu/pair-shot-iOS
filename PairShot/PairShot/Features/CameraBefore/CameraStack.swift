@preconcurrency import AVFoundation
import SwiftUI

// P10b — extracted from `BeforeCameraView.swift` so the top-level view
// stays under the 250-line cap. This file holds the camera-layer
// composite (preview + overlays + control bars + shutter row) plus the
// small helper subviews it needs.

/// Live-camera content for the Before flow. The parent passes in every
/// piece of state and every callback — `BeforeCameraStack` itself owns
/// no `@State`, which lets the parent retain the gesture-base values
/// across rebuilds.
struct BeforeCameraStack: View {
    let captureSession: AVCaptureSession
    let onMakePreviewView: (CameraPreviewView) -> Void
    let previewLayerProvider: () -> AVCaptureVideoPreviewLayer?

    let isGridOn: Bool
    let isLevelOn: Bool
    let rollDegrees: Double
    let flashMode: CameraFlashMode
    let lensPosition: CameraLensPosition

    let activePreset: ZoomPreset?
    let isPresetSupported: (ZoomPreset) -> Bool
    let exposureRangeProvider: () -> ClosedRange<Float>?
    let focusIndicator: Binding<FocusIndicatorState?>

    let isCapturing: Bool
    let capturedThumbnail: UIImage?

    let onTapFocus: (CGPoint) -> Void
    let onExposureBias: (Float) -> Void
    let pinchGesture: AnyGesture<Void>

    let onCycleFlash: () -> Void
    let onToggleLens: () -> Void
    let onToggleGrid: () -> Void
    let onToggleLevel: () -> Void
    let onApplyPreset: (ZoomPreset) -> Void
    let onShutter: () -> Void

    var body: some View {
        ZStack {
            BeforeCameraPreviewLayer(
                session: captureSession,
                onMakeView: onMakePreviewView
            )
            .ignoresSafeArea()

            if isGridOn {
                GridOverlay()
                    .ignoresSafeArea()
            }

            FocusGestureView(
                previewLayerProvider: previewLayerProvider,
                onTapFocus: onTapFocus,
                onExposureBias: onExposureBias,
                exposureRangeProvider: exposureRangeProvider,
                indicator: focusIndicator
            )
            .ignoresSafeArea()
            .gesture(pinchGesture)

            if let indicator = focusIndicator.wrappedValue {
                FocusReticleView(state: indicator)
            }

            VStack {
                CameraControlBar(
                    flashMode: flashMode,
                    lensPosition: lensPosition,
                    isGridOn: isGridOn,
                    isLevelOn: isLevelOn,
                    onCycleFlash: onCycleFlash,
                    onToggleLens: onToggleLens,
                    onToggleGrid: onToggleGrid,
                    onToggleLevel: onToggleLevel
                )

                if isLevelOn {
                    LevelIndicator(rollDegrees: rollDegrees)
                        .padding(.top, 4)
                }

                Spacer()

                ZoomControl(
                    activePreset: activePreset,
                    isSupported: isPresetSupported,
                    onSelect: onApplyPreset
                )
                .padding(.bottom, 12)

                HStack(alignment: .center) {
                    ThumbnailWell(image: capturedThumbnail)
                        .padding(.leading, 24)

                    Spacer()

                    CaptureShutterButton(isCapturing: isCapturing, action: onShutter)

                    Spacer()

                    Color.clear.frame(width: 56, height: 56).padding(.trailing, 24)
                }
                .padding(.bottom, 16)
            }
        }
    }
}

/// Small wrapper around `CameraPreview` that reports the underlying UIView
/// up to the parent so it can be used for tap-to-device-point conversion.
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

/// Last-captured thumbnail. Round corner placeholder when nil.
struct ThumbnailWell: View {
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
