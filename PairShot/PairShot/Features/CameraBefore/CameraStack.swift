@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct BeforeCameraStack: View {
    let captureSession: AVCaptureSession
    let onMakePreviewView: (CameraPreviewView) -> Void
    let previewLayerProvider: () -> AVCaptureVideoPreviewLayer?

    let isGridOn: Bool
    let isLevelOn: Bool
    let isNightModeOn: Bool
    let flashMode: CameraFlashMode
    let rollDegrees: Double

    let presets: [ZoomPresetSpec]
    let displayMultiplier: Double
    let activePreset: ZoomPresetSpec?
    let isDraggingZoom: Bool
    let currentZoomRatio: Double
    let minZoomRatio: Double
    let maxZoomRatio: Double
    let exposureRangeProvider: () -> ClosedRange<Float>?
    let focusIndicator: Binding<FocusIndicatorState?>

    let isCapturing: Bool
    let lastThumbnail: UIImage?

    let pendingPairs: [PhotoPair]

    let onTapFocus: (CGPoint) -> Void
    let onExposureBias: (Float) -> Void
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
    let onSettingsTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let layout = CameraLayoutMath.compute(totalSize: geo.size)

            ZStack(alignment: .top) {
                Color.appCameraBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    previewArea(width: layout.previewWidth, height: layout.previewHeight)
                        .frame(width: layout.previewWidth, height: layout.previewHeight)
                        .background(Color.appCameraBackground)

                    BeforeCameraStrip(
                        pendingPairs: pendingPairs
                    )
                    .frame(height: layout.stripHeight)
                    .clipped()

                    CameraBottomBar(
                        lastThumbnail: lastThumbnail,
                        isCapturing: isCapturing,
                        onLeadingTap: onLeadingTap,
                        onShutter: onShutter,
                        onSettingsTap: onSettingsTap
                    )
                    .frame(height: layout.bottomBarHeight)
                    .clipped()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                BannerAdSlot()
                    .frame(maxWidth: .infinity, maxHeight: layout.bannerHeight, alignment: .top)
                    .clipped()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func previewArea(width: CGFloat, height previewHeight: CGFloat) -> some View {
        ZStack {
            BeforeCameraPreviewLayer(
                session: captureSession,
                onMakeView: onMakePreviewView
            )
            .clipped()

            if isGridOn {
                GridOverlay()
                    .allowsHitTesting(false)
            }

            FocusGestureView(
                previewLayerProvider: previewLayerProvider,
                onTapFocus: onTapFocus,
                onExposureBias: onExposureBias,
                exposureRangeProvider: exposureRangeProvider,
                indicator: focusIndicator
            )
            .gesture(pinchGesture)

            if let indicator = focusIndicator.wrappedValue {
                FocusReticleView(state: indicator)
            }

            levelOverlay
            zoomBottomOverlay
        }
        .frame(width: width, height: previewHeight)
        .background(Color.appCameraBackground)
    }

    @ViewBuilder
    private var levelOverlay: some View {
        if isLevelOn {
            VStack {
                Spacer().frame(height: 24)
                LevelIndicator(rollDegrees: rollDegrees)
                Spacer()
            }
        }
    }

    private var zoomBottomOverlay: some View {
        VStack {
            Spacer()
            ZStack(alignment: .trailing) {
                if !presets.isEmpty {
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

struct CameraLayoutResult {
    let bannerHeight: CGFloat
    let previewWidth: CGFloat
    let previewHeight: CGFloat
    let stripHeight: CGFloat
    let bottomBarHeight: CGFloat
}

enum CameraLayoutMath {
    static let preferredBottomBarHeight: CGFloat = 116

    @MainActor
    static func compute(totalSize: CGSize) -> CameraLayoutResult {
        let banner = BannerAdSize.adaptiveHeight(width: totalSize.width)
        let preferredPreview = totalSize.width * 4.0 / 3.0
        let previewHeight = min(preferredPreview, max(0, totalSize.height))
        let bottomTotal = max(0, totalSize.height - previewHeight)
        let preferredStrip = StripDesign.stripHeight
        let preferredBottomTotal = preferredStrip + preferredBottomBarHeight

        let strip: CGFloat
        let bottomBar: CGFloat
        if bottomTotal >= preferredBottomTotal {
            strip = preferredStrip
            bottomBar = bottomTotal - preferredStrip
        } else {
            let stripRatio = preferredStrip / preferredBottomTotal
            strip = bottomTotal * stripRatio
            bottomBar = bottomTotal - strip
        }

        return CameraLayoutResult(
            bannerHeight: banner,
            previewWidth: totalSize.width,
            previewHeight: previewHeight,
            stripHeight: strip,
            bottomBarHeight: bottomBar
        )
    }
}
