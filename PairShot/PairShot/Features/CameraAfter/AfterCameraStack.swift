@preconcurrency import AVFoundation
import SwiftUI
import UIKit

// P10b — extracted from `AfterCameraView.swift` so the top-level view
// stays under the 250-line cap. This file owns the camera composite
// (preview + ghost overlay + control row) plus the small
// presentation-only subviews (top counters / shutter row / preview
// representable).

/// Live-camera content for the After flow. Pure presentation; the
/// parent owns all state and forwards callbacks/bindings.
struct AfterCameraStack: View {
    let captureSession: AVCaptureSession
    let onMakePreviewView: (CameraPreviewView) -> Void

    let ghostImage: UIImage?
    let alpha: Binding<Double>

    let pendingCount: Int
    let completedCount: Int

    let activePreset: ZoomPreset?
    let isPresetSupported: (ZoomPreset) -> Bool

    let isCapturing: Bool
    let canCapture: Bool

    let pinchGesture: AnyGesture<Void>
    let onApplyPreset: (ZoomPreset) -> Void
    let onShutter: () -> Void

    var body: some View {
        ZStack {
            AfterCameraPreviewLayer(
                session: captureSession,
                onMakeView: onMakePreviewView
            )
            .ignoresSafeArea()

            GhostOverlayView(image: ghostImage, alpha: alpha.wrappedValue)
                .ignoresSafeArea()

            // Pinch zoom override (P3.3). Tap area covers the full preview.
            Color.clear
                .contentShape(Rectangle())
                .gesture(pinchGesture)
                .ignoresSafeArea()

            VStack {
                AfterCameraTopBar(
                    pendingCount: pendingCount,
                    completedCount: completedCount
                )

                Spacer()

                GhostOverlayAlphaSlider(alpha: alpha)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                ZoomControl(
                    activePreset: activePreset,
                    isSupported: isPresetSupported,
                    onSelect: onApplyPreset
                )
                .padding(.bottom, 12)

                AfterCameraShutterRow(
                    isCapturing: isCapturing,
                    enabled: canCapture,
                    action: onShutter
                )
                .padding(.bottom, 16)
            }
        }
    }
}

/// Header strip showing how many pairs are still pending vs completed.
/// Pure presentation; no interaction.
struct AfterCameraTopBar: View {
    let pendingCount: Int
    let completedCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            badge(
                label: String(localized: "남은 페어"),
                value: pendingCount,
                tint: .yellow
            )
            badge(
                label: String(localized: "완료"),
                value: completedCount,
                tint: .green
            )
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }

    private func badge(label: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white)
            Text("\(value)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.5)))
    }
}

/// Shutter row reused in After flow. Same layout as Before, but with no
/// thumbnail well (the ghost overlay tells the user what they just shot).
struct AfterCameraShutterRow: View {
    let isCapturing: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Color.clear.frame(width: 56, height: 56).padding(.leading, 24)
            Spacer()
            CaptureShutterButton(isCapturing: isCapturing, action: action)
                .opacity(enabled ? 1.0 : 0.4)
                .disabled(!enabled)
            Spacer()
            Color.clear.frame(width: 56, height: 56).padding(.trailing, 24)
        }
    }
}

/// Mirror of `BeforeCameraPreviewLayer`. We keep a separate type so the
/// Feature directory boundary in `audit-arch` stays clean (CameraAfter must
/// not import CameraBefore).
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
