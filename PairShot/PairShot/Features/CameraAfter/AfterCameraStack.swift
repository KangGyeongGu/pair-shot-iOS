@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct AfterCameraStack: View {
    @Environment(Membership.self) private var membership
    @Environment(TutorialCoordinator.self) private var tutorialCoordinator

    let captureSession: AVCaptureSession
    let onMakePreviewView: (CameraPreviewView) -> Void

    let aspect: AspectRatio
    let ghostImage: UIImage?
    let ghostRotationDegrees: Double
    let rotationGuideDirection: RotationGuideDirection
    let alpha: Double
    let overlayEnabled: Bool

    let pairs: [PhotoPair]
    let selectedPairId: Binding<UUID?>

    let isGridOn: Bool

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
    let onSettingsTap: () -> Void
    var onStripPeek: ((UUID) -> Void)?

    var body: some View {
        GeometryReader { geo in
            let layout = CameraLayoutMath.compute(
                totalSize: geo.size,
                isAdFree: AdSuppression.isSuppressed(
                    membership: membership,
                    tutorialCoordinator: tutorialCoordinator,
                ),
                aspect: aspect,
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
                                y: layout.previewTopInsetInSlot,
                            )
                    }
                    .frame(width: layout.slotWidth, height: layout.slotHeight)

                    AfterCameraStrip(
                        pairs: pairs,
                        selectedPairId: selectedPairId,
                        stripZoneHeight: layout.stripHeight,
                        onPeek: onStripPeek,
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.stripHeight)
                    .clipped()
                    .tutorialAnchor(TutorialAnchorID.afterStrip)

                    CameraBottomBar(
                        isCapturing: isCapturing,
                        zoneHeight: layout.shutterHeight,
                        onLeadingTap: onLeadingTap,
                        onShutter: onShutter,
                        onSettingsTap: onSettingsTap,
                        shutterAnchorID: TutorialAnchorID.afterShutter,
                        leadingAnchorID: TutorialAnchorID.afterHomeButton,
                    )
                    .opacity(canCapture ? 1.0 : 0.6)
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
                        onDragEnded: onZoomDragEnded,
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

    private func previewArea(width: CGFloat, height previewHeight: CGFloat) -> some View {
        ZStack {
            AfterCameraPreviewLayer(
                session: captureSession,
                onMakeView: onMakePreviewView,
            )
            .clipped()

            GhostOverlayView(
                image: ghostImage,
                alpha: alpha,
                isEnabled: overlayEnabled,
                rotationDegrees: ghostRotationDegrees,
                width: width,
                height: previewHeight,
            )

            if isGridOn {
                GridOverlay()
                    .allowsHitTesting(false)
            }

            Color.clear
                .contentShape(Rectangle())
                .gesture(pinchGesture)

            RotationGuideOverlay(direction: rotationGuideDirection)
                .allowsHitTesting(false)

            zoomBottomOverlay
        }
        .frame(width: width, height: previewHeight)
        .background(Color.appCameraBackground)
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
