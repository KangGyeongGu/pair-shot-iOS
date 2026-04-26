@preconcurrency import AVFoundation
import SwiftUI

struct FocusIndicatorState: Equatable {
    var location: CGPoint
    var opacity: Double
    var exposureBias: Float
}

enum FocusGestureMath {
    static func biasForDrag(
        dragY: CGFloat,
        viewHeight: CGFloat,
        startBias: Float,
        range: ClosedRange<Float>
    ) -> Float {
        guard viewHeight > 0 else { return startBias }
        let span = range.upperBound - range.lowerBound
        let fraction = Float(-dragY / viewHeight)
        let candidate = startBias + fraction * span
        return max(range.lowerBound, min(candidate, range.upperBound))
    }

    @MainActor
    static func devicePoint(
        forTap point: CGPoint,
        in previewLayer: AVCaptureVideoPreviewLayer?
    ) -> CGPoint {
        guard let previewLayer else { return CGPoint(x: 0.5, y: 0.5) }
        return previewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
}

struct FocusGestureView: View {
    let previewLayerProvider: () -> AVCaptureVideoPreviewLayer?
    let onTapFocus: (CGPoint) -> Void
    let onExposureBias: (Float) -> Void
    let exposureRangeProvider: () -> ClosedRange<Float>?

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
            withAnimation(.easeOut(duration: 0.4)) {
                if indicator?.location == location {
                    indicator?.opacity = 0
                }
            }
        }
    }
}

struct FocusReticleView: View {
    let state: FocusIndicatorState

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.yellow, lineWidth: 1.5)
                .frame(width: 72, height: 72)

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
