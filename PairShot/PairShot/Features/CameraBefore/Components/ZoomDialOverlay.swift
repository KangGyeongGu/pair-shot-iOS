import SwiftUI

struct ZoomDialOverlay: View {
    let currentRatio: Double
    let minRatio: Double
    let maxRatio: Double
    let displayMultiplier: Double

    var body: some View {
        VStack(spacing: 4) {
            zoomCaption
            ruler
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "camera_desc_zoom_dial"))
        .accessibilityValue(formatZoomLabel(displayedCurrent))
    }

    private var zoomCaption: some View {
        Text(formatZoomLabel(displayedCurrent))
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.6)))
    }

    private var ruler: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                drawTicksAndLabels(ctx: ctx, size: size)
                drawIndicator(ctx: ctx, size: size)
            }
            .frame(width: geo.size.width, height: ZoomDialDesign.rulerHeight)
        }
        .frame(height: ZoomDialDesign.rulerHeight)
        .frame(maxWidth: .infinity)
    }

    private var displayedCurrent: Double {
        currentRatio * displayMultiplier
    }

    private var displayedMin: Double {
        minRatio * displayMultiplier
    }

    private var displayedMax: Double {
        maxRatio * displayMultiplier
    }

    init(
        currentRatio: Double,
        minRatio: Double,
        maxRatio: Double,
        displayMultiplier: Double = 1.0
    ) {
        self.currentRatio = currentRatio
        self.minRatio = minRatio
        self.maxRatio = maxRatio
        self.displayMultiplier = displayMultiplier
    }

    private func drawTicksAndLabels(ctx: GraphicsContext, size: CGSize) {
        let span = max(displayedMax - displayedMin, 0.0001)
        let pxPerZoom = ZoomDialMetrics.dragRangeSpanPt / span
        let centerX = size.width / 2
        let baselineY = size.height - ZoomDialDesign.tickBottomInset
        let visibleHalfSpan = (size.width / 2) / pxPerZoom
        let visibleMin = max(displayedMin, displayedCurrent - visibleHalfSpan)
        let visibleMax = min(displayedMax, displayedCurrent + visibleHalfSpan)
        let startHalf = Int((visibleMin * 2).rounded(.down))
        let endHalf = Int((visibleMax * 2).rounded(.up))
        guard startHalf <= endHalf else { return }
        for halfStep in startHalf ... endHalf {
            let value = Double(halfStep) / 2.0
            if value < displayedMin - 0.001 || value > displayedMax + 0.001 { continue }
            let offset = (value - displayedCurrent) * pxPerZoom
            let x = centerX + offset
            if x < 0 || x > size.width { continue }
            let isMajor = halfStep.isMultiple(of: 2)
            drawTick(ctx: ctx, x: x, baselineY: baselineY, isMajor: isMajor)
            if isMajor {
                drawLabel(
                    ctx: ctx,
                    x: x,
                    baselineY: baselineY,
                    value: value
                )
            }
        }
    }

    private func drawTick(ctx: GraphicsContext, x: CGFloat, baselineY: CGFloat, isMajor: Bool) {
        let height: CGFloat = isMajor ? ZoomDialDesign.majorTickHeight : ZoomDialDesign.minorTickHeight
        let width: CGFloat = isMajor ? ZoomDialDesign.majorTickWidth : ZoomDialDesign.minorTickWidth
        let alpha: Double = isMajor ? 1.0 : 0.5
        var path = Path()
        path.move(to: CGPoint(x: x, y: baselineY - height))
        path.addLine(to: CGPoint(x: x, y: baselineY))
        ctx.stroke(path, with: .color(Color.white.opacity(alpha)), lineWidth: width)
    }

    private func drawLabel(ctx: GraphicsContext, x: CGFloat, baselineY: CGFloat, value: Double) {
        let label = formatTickLabel(value)
        let resolved = ctx.resolve(
            Text(label)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundColor(.white.opacity(0.85))
        )
        let labelSize = resolved.measure(in: CGSize(width: 40, height: 20))
        let labelOrigin = CGPoint(
            x: x - labelSize.width / 2,
            y: baselineY - ZoomDialDesign.majorTickHeight - labelSize.height - 1
        )
        ctx.draw(resolved, at: CGPoint(x: labelOrigin.x + labelSize.width / 2, y: labelOrigin.y + labelSize.height / 2))
    }

    private func drawIndicator(ctx: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        let baselineY = size.height - ZoomDialDesign.tickBottomInset
        var bar = Path()
        bar.move(to: CGPoint(x: centerX, y: baselineY - ZoomDialDesign.indicatorHeight))
        bar.addLine(to: CGPoint(x: centerX, y: baselineY))
        ctx.stroke(bar, with: .color(Color.accentColor), lineWidth: ZoomDialDesign.indicatorWidth)

        var chevron = Path()
        let tipY = baselineY - ZoomDialDesign.indicatorHeight - 1
        chevron.move(to: CGPoint(x: centerX - 5, y: tipY - 5))
        chevron.addLine(to: CGPoint(x: centerX + 5, y: tipY - 5))
        chevron.addLine(to: CGPoint(x: centerX, y: tipY))
        chevron.closeSubpath()
        ctx.fill(chevron, with: .color(Color.accentColor))
    }

    private func formatZoomLabel(_ ratio: Double) -> String {
        if abs(ratio - ratio.rounded()) < 0.05 {
            return "\(Int(ratio.rounded()))x"
        }
        return String(format: "%.1fx", ratio)
    }

    private func formatTickLabel(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.01 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }
}

enum ZoomDialDesign {
    static let rulerHeight: CGFloat = 38
    static let tickBottomInset: CGFloat = 2
    static let majorTickHeight: CGFloat = 14
    static let majorTickWidth: CGFloat = 2
    static let minorTickHeight: CGFloat = 8
    static let minorTickWidth: CGFloat = 1
    static let indicatorHeight: CGFloat = 18
    static let indicatorWidth: CGFloat = 2
}

#Preview {
    ZStack {
        Color.appCameraBackground
        ZoomDialOverlay(currentRatio: 1.3, minRatio: 0.5, maxRatio: 5.0, displayMultiplier: 1.0)
            .padding()
    }
}
