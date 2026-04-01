import SwiftUI
import UIKit

struct ZoomControlView: View {
    var availableFactors: [CGFloat]
    var currentFactor: CGFloat
    var minFactor: CGFloat = 1.0
    var maxFactor: CGFloat = 15.0
    var zoomDivisor: CGFloat = 2.0
    var onZoomChanged: (CGFloat) -> Void
    var onZoomDrag: (CGFloat) -> Void

    @State private var isDragging: Bool = false
    @State private var showDial: Bool = false  // 다이얼 표시 (딜레이 포함)
    @State private var dragStartX: CGFloat = 0
    @State private var dragStartFactor: CGFloat = 1.0
    @State private var lastSnappedFactor: CGFloat? = nil
    @State private var hideTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            if showDial {
                ZoomDialView(
                    currentFactor: currentFactor,
                    minFactor: minFactor,
                    maxFactor: maxFactor,
                    availableFactors: availableFactors,
                    zoomDivisor: zoomDivisor
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                ZoomButtonRow(
                    availableFactors: availableFactors,
                    currentFactor: currentFactor,
                    zoomDivisor: zoomDivisor,
                    onTap: onZoomChanged
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showDial)
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    hideTask?.cancel()
                    if !isDragging {
                        isDragging = true
                        showDial = true
                        dragStartX = value.startLocation.x
                        dragStartFactor = currentFactor
                        lastSnappedFactor = nil
                    }
                    let delta = value.location.x - dragStartX
                    let raw = logShiftedFactor(start: dragStartFactor, delta: delta)
                    let snapped = snapFactor(raw)
                    onZoomDrag(snapped)
                }
                .onEnded { _ in
                    isDragging = false
                    lastSnappedFactor = nil
                    // 손 뗀 후 1.2초 뒤에 다이얼 숨김
                    hideTask = Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        if !isDragging {
                            showDial = false
                        }
                    }
                }
        )
    }

    private func logShiftedFactor(start: CGFloat, delta: CGFloat) -> CGFloat {
        let screenWidth: CGFloat = 150
        let logMin = log(max(minFactor, 0.01))
        let logMax = log(max(maxFactor, 0.01))
        let logStart = log(max(start, 0.01))
        let logTarget = logStart + (-delta / screenWidth) * (logMax - logMin)
        return exp(min(max(logTarget, logMin), logMax))
    }

    private func snapFactor(_ raw: CGFloat) -> CGFloat {
        let snapThreshold = 0.03
        for factor in availableFactors {
            let ratio = abs(raw - factor) / factor
            if ratio <= snapThreshold {
                if lastSnappedFactor != factor {
                    lastSnappedFactor = factor
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                return factor
            }
        }
        lastSnappedFactor = nil
        return raw
    }
}

// MARK: - Button Row

private struct ZoomButtonRow: View {
    let availableFactors: [CGFloat]
    let currentFactor: CGFloat
    let zoomDivisor: CGFloat
    let onTap: (CGFloat) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(availableFactors, id: \.self) { factor in
                let selected = abs(currentFactor - factor) < 0.05
                Button { onTap(factor) } label: {
                    Text(displayLabel(factor))
                        .font(.system(size: selected ? 13 : 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? Color.yellow : Color.white)
                        .frame(width: selected ? 42 : 36, height: selected ? 42 : 36)
                        .background(
                            Circle()
                                .fill(.black.opacity(selected ? 0.65 : 0.45))
                                .overlay(
                                    Circle().strokeBorder(
                                        selected ? Color.yellow.opacity(0.55) : Color.white.opacity(0.12),
                                        lineWidth: selected ? 1.5 : 0.5
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: selected)
            }
        }
    }

    private func displayLabel(_ factor: CGFloat) -> String {
        let v = factor * zoomDivisor
        if v < 1.0 { return String(format: "%.1fx", v) }
        if abs(v - v.rounded()) < 0.05 { return "\(Int(v.rounded()))x" }
        return String(format: "%.1fx", v)
    }
}

// MARK: - Dial View

private struct ZoomDialView: View {
    let currentFactor: CGFloat
    let minFactor: CGFloat
    let maxFactor: CGFloat
    let availableFactors: [CGFloat]
    let zoomDivisor: CGFloat

    private let dialRadius: CGFloat = 300
    private let dialHeight: CGFloat = 48

    var body: some View {
        ZStack {
            SemiCircleBackground(radius: dialRadius)

            DialRuler(
                currentFactor: currentFactor,
                minFactor: minFactor,
                maxFactor: maxFactor,
                availableFactors: availableFactors,
                zoomDivisor: zoomDivisor,
                radius: dialRadius
            )

            // Center label
            VStack {
                Spacer()
                Text(currentLabel)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.yellow)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.04), value: currentLabel)
                    .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: dialHeight)
    }

    private var currentLabel: String {
        let v = currentFactor * zoomDivisor
        if abs(v - v.rounded()) < 0.05 { return "\(Int(v.rounded()))x" }
        return String(format: "%.1fx", v)
    }
}

private struct SemiCircleBackground: View {
    let radius: CGFloat
    // 부채꼴: 210도~330도 (120도 범위, 완전 반원보다 좁음)
    static let arcStart: Double = 210
    static let arcEnd: Double = 330

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height

            var arc = Path()
            arc.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: radius,
                startAngle: .degrees(Self.arcStart),
                endAngle: .degrees(Self.arcEnd),
                clockwise: true
            )
            arc.addLine(to: CGPoint(x: cx, y: cy))
            arc.closeSubpath()

            context.fill(arc, with: .color(.gray.opacity(0.35)))

            var borderArc = Path()
            borderArc.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: radius - 0.25,
                startAngle: .degrees(Self.arcStart),
                endAngle: .degrees(Self.arcEnd),
                clockwise: true
            )
            context.stroke(borderArc, with: .color(.white.opacity(0.18)), lineWidth: 0.5)
        }
    }
}

// MARK: - Dial Ruler Canvas

private struct DialRuler: View {
    let currentFactor: CGFloat
    let minFactor: CGFloat
    let maxFactor: CGFloat
    let availableFactors: [CGFloat]
    let zoomDivisor: CGFloat
    let radius: CGFloat

    // Arc spans 180° (π radians). Map log-zoom range onto it.
    // Left edge = minFactor, right edge = maxFactor.
    // currentFactor sits at the bottom-center (270° / -90° — pointing straight up from arc center).

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height          // arc center is at bottom of frame

            let logMin = log(max(minFactor, 0.01))
            let logMax = log(max(maxFactor, 0.01))
            let logCurrent = log(max(currentFactor, 0.01))

            // Normalize log position to [0,1]
            func norm(_ factor: CGFloat) -> CGFloat {
                (log(max(factor, 0.01)) - logMin) / (logMax - logMin)
            }

            let arcSpan: CGFloat = 120.0 // 부채꼴 각도 범위 (210~330)
            let currentNorm = (logCurrent - logMin) / (logMax - logMin)
            func angleDeg(_ n: CGFloat) -> CGFloat {
                270.0 + (n - currentNorm) * arcSpan
            }

            // Indicator line at bottom center (currentFactor)
            let indicatorAngle = angleDeg(currentNorm) * .pi / 180.0
            let innerR = radius - 22
            let outerR = radius - 4
            let ix = cx + cos(indicatorAngle) * (innerR - 4)
            let iy = cy + sin(indicatorAngle) * (innerR - 4)

            var indicatorPath = Path()
            indicatorPath.move(to: CGPoint(x: cx + cos(indicatorAngle) * outerR,
                                           y: cy + sin(indicatorAngle) * outerR))
            indicatorPath.addLine(to: CGPoint(x: ix, y: iy))
            context.stroke(indicatorPath, with: .color(Color.yellow), lineWidth: 2.5)

            // Tick mark generation:
            // We generate ticks in display-zoom space (0.1x increments), then map to norm.
            let displayMin = minFactor * zoomDivisor
            let displayMax = maxFactor * zoomDivisor
            let minorStep: CGFloat = 0.1

            // Only draw ticks whose angles fall within the visible arc (180°–360°, i.e. top semicircle).
            // Visible angle range from the offset: roughly ±90° around 270°.
            let visibleHalfSpan: CGFloat = 65.0  // 부채꼴 120도의 절반 + 약간 여유

            var displayVal = (displayMin / minorStep).rounded(.up) * minorStep
            while displayVal <= displayMax + minorStep * 0.5 {
                let internalFactor = displayVal / zoomDivisor
                let n = norm(internalFactor)
                let aDeg = angleDeg(n)

                // Only render ticks in the visible half-circle window
                let relDeg = aDeg - 270.0
                guard abs(relDeg) <= visibleHalfSpan else {
                    displayVal += minorStep
                    continue
                }

                let aRad = aDeg * .pi / 180.0

                // Classify tick
                let isMajor = availableFactors.contains { abs($0 - internalFactor) < minorStep * 0.4 }
                let displayRounded = (displayVal * 10).rounded() / 10
                let isMedium = !isMajor && abs(displayRounded.truncatingRemainder(dividingBy: 0.5)) < 0.05

                let tickLen: CGFloat = isMajor ? 18 : (isMedium ? 11 : 6)
                let tickAlpha: CGFloat = isMajor ? 0.9 : (isMedium ? 0.55 : 0.28)
                let tickWidth: CGFloat = isMajor ? 1.8 : (isMedium ? 1.0 : 0.7)

                let outerPt = CGPoint(x: cx + cos(aRad) * (radius - 2),
                                      y: cy + sin(aRad) * (radius - 2))
                let innerPt = CGPoint(x: cx + cos(aRad) * (radius - 2 - tickLen),
                                      y: cy + sin(aRad) * (radius - 2 - tickLen))

                var tick = Path()
                tick.move(to: outerPt)
                tick.addLine(to: innerPt)
                context.stroke(tick, with: .color(.white.opacity(tickAlpha)), lineWidth: tickWidth)

                if isMajor {
                    let labelR = radius - 2 - tickLen - 10
                    let labelPt = CGPoint(x: cx + cos(aRad) * labelR,
                                         y: cy + sin(aRad) * labelR)
                    let near = abs(currentFactor - internalFactor) < 0.08
                    context.draw(
                        Text(tickLabel(internalFactor))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle((near ? Color.yellow : Color.white).opacity(near ? 1.0 : 0.65)),
                        at: labelPt,
                        anchor: .center
                    )
                } else if isMedium {
                    let labelR = radius - 2 - tickLen - 8
                    let labelPt = CGPoint(x: cx + cos(aRad) * labelR,
                                         y: cy + sin(aRad) * labelR)
                    let near = abs(currentFactor - internalFactor) < 0.06
                    if near {
                        context.draw(
                            Text(tickLabel(internalFactor))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.75)),
                            at: labelPt,
                            anchor: .center
                        )
                    }
                }

                displayVal += minorStep
                displayVal = (displayVal * 100).rounded() / 100  // float drift fix
            }
        }
        .frame(width: radius * 2, height: radius + 8)
    }

    private func tickLabel(_ factor: CGFloat) -> String {
        let v = factor * zoomDivisor
        if v < 1.0 { return String(format: "%.1f", v) }
        if abs(v - v.rounded()) < 0.05 { return "\(Int(v.rounded()))x" }
        return String(format: "%.1f", v)
    }
}

// MARK: - Preview

#Preview("기본 상태") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            Spacer()
            ZoomControlView(
                availableFactors: [0.5, 1.0, 2.0, 3.0],
                currentFactor: 1.0,
                minFactor: 0.5,
                maxFactor: 15.0,
                zoomDivisor: 1.0,
                onZoomChanged: { _ in },
                onZoomDrag: { _ in }
            )
            ZoomControlView(
                availableFactors: [0.5, 1.0, 2.0, 3.0],
                currentFactor: 2.0,
                minFactor: 0.5,
                maxFactor: 15.0,
                zoomDivisor: 1.0,
                onZoomChanged: { _ in },
                onZoomDrag: { _ in }
            )
            Spacer()
        }
    }
}

#Preview("다이얼 상태") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            Spacer()
            ZoomDialView(
                currentFactor: 1.4,
                minFactor: 0.5,
                maxFactor: 15.0,
                availableFactors: [0.5, 1.0, 2.0, 3.0],
                zoomDivisor: 1.0
            )
            ZoomDialView(
                currentFactor: 2.4,
                minFactor: 0.5,
                maxFactor: 15.0,
                availableFactors: [0.5, 1.0, 2.0, 3.0],
                zoomDivisor: 1.0
            )
            Spacer()
        }
    }
}
