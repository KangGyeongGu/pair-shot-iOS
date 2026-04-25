@preconcurrency import AVFoundation
import SwiftUI

/// Visible state of the tap-to-focus indicator. Owned by the camera view.
struct FocusIndicatorState: Equatable {
    /// Position in view coordinates where the indicator is drawn.
    var location: CGPoint
    /// Used to fade the indicator in/out.
    var opacity: Double
    /// Current EV bias, displayed as a small "EV +1.0" label next to the reticle.
    var exposureBias: Float
}

/// Pure helpers used by `FocusGestureView` and exercised in unit tests.
/// Static so it can run off the main actor (no AVFoundation calls here).
enum FocusGestureMath {
    /// Convert a vertical drag distance (points) into an EV bias delta.
    /// - Parameters:
    ///   - dragY: Negative = upward (brighten), positive = downward (darken).
    ///   - viewHeight: Used so the same gesture spans the full EV range
    ///     regardless of device size.
    ///   - range: Device-reported EV bias range.
    /// - Returns: Bias clamped into `range`.
    static func biasForDrag(
        dragY: CGFloat,
        viewHeight: CGFloat,
        startBias: Float,
        range: ClosedRange<Float>
    ) -> Float {
        guard viewHeight > 0 else { return startBias }
        // Up = brighter → invert sign. Map full-height drag to full range span.
        let span = range.upperBound - range.lowerBound
        let fraction = Float(-dragY / viewHeight)
        let candidate = startBias + fraction * span
        return max(range.lowerBound, min(candidate, range.upperBound))
    }

    /// Convert a tap point in view coordinates to AVFoundation device space
    /// (0..1, 0..1). Falls back to the centre when the preview layer is missing.
    @MainActor
    static func devicePoint(
        forTap point: CGPoint,
        in previewLayer: AVCaptureVideoPreviewLayer?
    ) -> CGPoint {
        guard let previewLayer else { return CGPoint(x: 0.5, y: 0.5) }
        return previewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
}

/// SwiftUI overlay that adds tap-to-focus and vertical-drag EV to the camera
/// preview. Composes nicely above `CameraPreview` via `.overlay { FocusGestureView(...) }`.
struct FocusGestureView: View {
    /// Used for tap-to-device-point conversion. Captured once when the preview
    /// view is created.
    let previewLayerProvider: () -> AVCaptureVideoPreviewLayer?

    /// Forwarded to the actor: `await session.focus(at: devicePoint)`.
    let onTapFocus: (CGPoint) -> Void

    /// Forwarded as an absolute bias value (already clamped). Caller does
    /// `await session.setExposureBias(_)`.
    let onExposureBias: (Float) -> Void

    /// Provides the device's `(min, max)` EV bias range.
    let exposureRangeProvider: () -> ClosedRange<Float>?

    /// Pushed up so the parent view can render the reticle.
    @Binding var indicator: FocusIndicatorState?

    @State private var dragStartBias: Float?

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleTap(location: location)
                }
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            handleDrag(value: value, viewHeight: proxy.size.height)
                        }
                        .onEnded { _ in
                            dragStartBias = nil
                        }
                )
        }
    }

    private func handleTap(location: CGPoint) {
        let layer = previewLayerProvider()
        let devicePoint = FocusGestureMath.devicePoint(forTap: location, in: layer)
        onTapFocus(devicePoint)
        showIndicator(at: location)
    }

    private func handleDrag(value: DragGesture.Value, viewHeight: CGFloat) {
        guard let range = exposureRangeProvider() else { return }
        if dragStartBias == nil {
            dragStartBias = indicator?.exposureBias ?? 0
        }
        let bias = FocusGestureMath.biasForDrag(
            dragY: value.translation.height,
            viewHeight: viewHeight,
            startBias: dragStartBias ?? 0,
            range: range
        )
        onExposureBias(bias)
        // If we have an indicator anchor, just refresh the bias label and keep visible.
        if var current = indicator {
            current.exposureBias = bias
            current.opacity = 1.0
            indicator = current
        }
    }

    private func showIndicator(at location: CGPoint) {
        let bias = indicator?.exposureBias ?? 0
        indicator = FocusIndicatorState(location: location, opacity: 1.0, exposureBias: bias)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            // Fade only if no newer tap arrived in the meantime.
            withAnimation(.easeOut(duration: 0.4)) {
                if indicator?.location == location {
                    indicator?.opacity = 0
                }
            }
        }
    }
}

/// Rendered reticle. Kept separate from the gesture overlay so the gesture
/// layer can remain a thin transparent rectangle.
struct FocusReticleView: View {
    let state: FocusIndicatorState

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.yellow, lineWidth: 1.5)
                .frame(width: 72, height: 72)

            // EV label to the right of the reticle.
            Text(biasLabel)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.yellow)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.black.opacity(0.5)))
                .offset(x: 56)
        }
        .position(state.location)
        .opacity(state.opacity)
        .allowsHitTesting(false)
    }

    private var biasLabel: String {
        let sign = state.exposureBias >= 0 ? "+" : ""
        return String(format: "EV \(sign)%.1f", state.exposureBias)
    }
}
