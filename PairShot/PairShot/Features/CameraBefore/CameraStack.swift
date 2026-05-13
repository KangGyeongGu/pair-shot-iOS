@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct BeforeCameraStack: View {
    @Environment(AdFreeStore.self) private var adFreeStore

    let captureSession: AVCaptureSession
    let onMakePreviewView: (CameraPreviewView) -> Void
    let previewLayerProvider: () -> AVCaptureVideoPreviewLayer?

    let aspect: AspectRatio
    let isGridOn: Bool
    let isLevelOn: Bool
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
    let activePairId: UUID?

    let onTapFocus: (CGPoint) -> Void
    let onExposureBias: (Float) -> Void
    let pinchGesture: AnyGesture<Void>

    let onApplyPreset: (ZoomPresetSpec) -> Void
    let onZoomDragChanged: (Double) -> Void
    let onZoomDragEnded: () -> Void
    let onShutter: () -> Void
    let onLeadingTap: () -> Void
    let onToggleLens: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let layout = CameraLayoutMath.compute(
                totalSize: geo.size,
                isAdFree: adFreeStore.isAdFree,
                aspect: aspect
            )

            ZStack(alignment: .top) {
                Color.appCameraBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        Color.appLetterbox

                        previewArea(width: layout.previewWidth, height: layout.previewHeight)
                            .frame(width: layout.previewWidth, height: layout.previewHeight)
                            .offset(
                                x: layout.previewLeadingInsetInSlot,
                                y: layout.previewTopInsetInSlot
                            )
                    }
                    .frame(width: layout.slotWidth, height: layout.slotHeight)

                    BeforeCameraStrip(
                        pendingPairs: pendingPairs,
                        activePairId: activePairId,
                        stripZoneHeight: layout.stripHeight
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.stripHeight)
                    .clipped()

                    CameraBottomBar(
                        lastThumbnail: lastThumbnail,
                        isCapturing: isCapturing,
                        zoneHeight: layout.shutterHeight,
                        onLeadingTap: onLeadingTap,
                        onShutter: onShutter,
                        onSettingsTap: onSettingsTap
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.shutterHeight)
                    .clipped()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if !layout.isAdFree {
                    BannerAdSlot()
                        .frame(maxWidth: .infinity, maxHeight: layout.bannerHeight, alignment: .top)
                        .clipped()
                        .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
    let isAdFree: Bool
    let bannerHeight: CGFloat
    let slotWidth: CGFloat
    let slotHeight: CGFloat
    let previewWidth: CGFloat
    let previewHeight: CGFloat
    let previewLeadingInsetInSlot: CGFloat
    let previewTopInsetInSlot: CGFloat
    let stripHeight: CGFloat
    let shutterHeight: CGFloat
}

enum CameraLayoutMath {
    private struct PreviewPlacement {
        let width: CGFloat
        let height: CGFloat
        let leadingInset: CGFloat
        let topInset: CGFloat
    }

    static let stripZoneRatio: CGFloat = 168.0 / 284.0
    static let slotAspectMultiplier: CGFloat = 4.0 / 3.0

    @MainActor
    static func compute(
        totalSize: CGSize,
        isAdFree: Bool,
        aspect: AspectRatio
    ) -> CameraLayoutResult {
        let bannerHeight: CGFloat = isAdFree ? 0 : BannerAdSize.adaptiveHeight(width: totalSize.width)

        let slotWidth = max(0, totalSize.width)
        let slotHeight = min(slotWidth * slotAspectMultiplier, max(0, totalSize.height))

        let preview = previewPlacement(
            slotWidth: slotWidth,
            slotHeight: slotHeight,
            aspect: aspect
        )

        let remaining = max(0, totalSize.height - slotHeight)
        let stripHeight = remaining * stripZoneRatio
        let shutterHeight = remaining - stripHeight

        return CameraLayoutResult(
            isAdFree: isAdFree,
            bannerHeight: bannerHeight,
            slotWidth: slotWidth,
            slotHeight: slotHeight,
            previewWidth: preview.width,
            previewHeight: preview.height,
            previewLeadingInsetInSlot: preview.leadingInset,
            previewTopInsetInSlot: preview.topInset,
            stripHeight: stripHeight,
            shutterHeight: shutterHeight
        )
    }

    private static func previewPlacement(
        slotWidth: CGFloat,
        slotHeight: CGFloat,
        aspect: AspectRatio
    ) -> PreviewPlacement {
        switch aspect {
            case .fourThree:
                return PreviewPlacement(
                    width: slotWidth,
                    height: slotHeight,
                    leadingInset: 0,
                    topInset: 0
                )

            case .square:
                let side = min(slotWidth, slotHeight)
                let leading = max(0, (slotWidth - side) / 2)
                let top = max(0, (slotHeight - side) / 2)
                return PreviewPlacement(
                    width: side,
                    height: side,
                    leadingInset: leading,
                    topInset: top
                )

            case .sixteenNine:
                let portraitMultiplier = aspect.portraitHeightMultiplier
                let widthByHeight = slotHeight / portraitMultiplier
                let width = min(slotWidth, widthByHeight)
                let height = width * portraitMultiplier
                let leading = max(0, (slotWidth - width) / 2)
                let top = max(0, (slotHeight - height) / 2)
                return PreviewPlacement(
                    width: width,
                    height: height,
                    leadingInset: leading,
                    topInset: top
                )
        }
    }
}
