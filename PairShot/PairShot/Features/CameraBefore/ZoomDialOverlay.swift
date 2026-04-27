import SwiftUI

struct ZoomDialOverlay: View {
    let currentRatio: Double
    let minRatio: Double
    let maxRatio: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(formatZoomLabel(currentRatio))
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.5))
                )

            Canvas { ctx, size in
                drawTicks(ctx: ctx, size: size)
                drawIndicator(ctx: ctx, size: size)
            }
            .frame(height: 24)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "camera_desc_zoom_dial"))
        .accessibilityValue(formatZoomLabel(currentRatio))
    }

    private func drawTicks(ctx: GraphicsContext, size: CGSize) {
        let span = max(maxRatio - minRatio, 0.0001)
        let pxPerZoom = ZoomDialMetrics.dragRangeSpanPt / span
        let centerX = size.width / 2
        let canvasH = size.height
        let visibleSpan = size.width / pxPerZoom
        let visibleMin = max(minRatio, currentRatio - visibleSpan / 2)
        let visibleMax = min(maxRatio, currentRatio + visibleSpan / 2)
        let startTick = Int((visibleMin * 10).rounded(.down))
        let endTick = Int((visibleMax * 10).rounded(.up))
        guard startTick <= endTick else { return }
        for i in startTick ... endTick {
            let tick = Double(i) / 10.0
            let offset = (tick - currentRatio) * pxPerZoom
            let x = centerX + offset
            if x < 0 || x > size.width { continue }
            let isMajor = i.isMultiple(of: 10)
            let tickHeight: CGFloat = isMajor ? 14 : 6
            let tickWidth: CGFloat = isMajor ? 2 : 1
            let tickColor: Color = isMajor ? .white : .white.opacity(0.5)
            let topY = canvasH - tickHeight
            var path = Path()
            path.move(to: CGPoint(x: x, y: topY))
            path.addLine(to: CGPoint(x: x, y: canvasH))
            ctx.stroke(path, with: .color(tickColor), lineWidth: tickWidth)
        }
    }

    private func drawIndicator(ctx: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        let canvasH = size.height
        var indicator = Path()
        indicator.move(to: CGPoint(x: centerX, y: canvasH - 20))
        indicator.addLine(to: CGPoint(x: centerX, y: canvasH))
        ctx.stroke(indicator, with: .color(.yellow), lineWidth: 2)
    }

    private func formatZoomLabel(_ ratio: Double) -> String {
        if abs(ratio - ratio.rounded()) < 0.05 {
            return "\(Int(ratio.rounded()))x"
        }
        return String(format: "%.1fx", ratio)
    }
}

#Preview {
    ZStack {
        Color.appCameraBackground
        ZoomDialOverlay(currentRatio: 1.3, minRatio: 0.5, maxRatio: 5.0)
            .padding()
    }
}
