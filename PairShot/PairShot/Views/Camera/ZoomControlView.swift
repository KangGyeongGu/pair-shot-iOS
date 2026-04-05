import SwiftUI
import UIKit

struct ZoomControlView: View {
    var availableFactors: [CGFloat] // 버튼용 (0.5x, 1x, 2x, 3x)
    var allFixedFactors: [CGFloat] = []
    var focalLengthMap: [CGFloat: Int] = [:]
    var currentFactor: CGFloat
    var minFactor: CGFloat = 1.0
    var maxFactor: CGFloat = 15.0
    var zoomDivisor: CGFloat = 2.0
    var onZoomChanged: (CGFloat) -> Void
    var onZoomDrag: (CGFloat) -> Void

    @State private var showDial = false
    @State private var dragStartX: CGFloat = 0
    @State private var dragStartFactor: CGFloat = 1.0
    @State private var lastSnappedFactor: CGFloat?
    @State private var hideTask: Task<Void, Never>?
    @State private var isLongPressing = false
    @State private var dragStartLocation: CGPoint = .zero
    @State private var didDrag = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 다이얼 오버레이 (터치 투과 — hitTest 안 받음)
                if showDial {
                    CircleDialOverlay(
                        currentFactor: currentFactor,
                        minFactor: minFactor,
                        maxFactor: maxFactor,
                        availableFactors: allFixedFactors.isEmpty ? availableFactors : allFixedFactors,
                        focalLengthMap: focalLengthMap,
                        zoomDivisor: zoomDivisor,
                        size: geo.size
                    )
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.2), value: showDial)
                }

                // 배율 버튼 행 (하단 고정, 터치 영역은 여기만)
                VStack {
                    Spacer()
                    ZoomButtonRow(
                        availableFactors: availableFactors,
                        currentFactor: currentFactor,
                        zoomDivisor: zoomDivisor,
                        onTap: { factor in
                            onZoomChanged(factor)
                        }
                    )
                    .opacity(showDial ? 0 : 1)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 20)
                    .frame(height: 60)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4)
                            .onEnded { _ in
                                guard !showDial else { return }
                                isLongPressing = true
                                showDial = true
                                hideTask?.cancel()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                hideTask?.cancel()
                                if dragStartLocation == .zero {
                                    dragStartLocation = value.startLocation
                                    dragStartFactor = currentFactor
                                    didDrag = false
                                }
                                let distance = abs(value.translation.width)
                                if distance > 12 {
                                    didDrag = true
                                    if !showDial {
                                        showDial = true
                                        isLongPressing = false
                                        dragStartX = value.location.x
                                        dragStartFactor = currentFactor
                                        lastSnappedFactor = nil
                                    }
                                }
                                if showDial, didDrag {
                                    if isLongPressing {
                                        isLongPressing = false
                                        dragStartX = value.location.x
                                        dragStartFactor = currentFactor
                                        lastSnappedFactor = nil
                                    }
                                    let delta = value.location.x - dragStartX
                                    let raw = logShiftedFactor(start: dragStartFactor, delta: delta)
                                    let snapped = snapFactor(raw)
                                    onZoomDrag(snapped)
                                }
                            }
                            .onEnded { _ in
                                isLongPressing = false
                                didDrag = false
                                dragStartLocation = .zero
                                lastSnappedFactor = nil
                                if showDial {
                                    hideTask = Task {
                                        try? await Task.sleep(for: .seconds(1.5))
                                        showDial = false
                                    }
                                }
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 비선형 norm: 버튼 배율 범위 → 촘촘, 그 이상 → 넓음
    /// boundary = 버튼의 마지막 고정 배율 (3x의 내부값)
    private var boundaryFactor: CGFloat {
        availableFactors.last ?? maxFactor * 0.3
    }

    /// 버튼 배율 범위가 전체의 30%, 나머지 70%
    private var lowRatio: CGFloat {
        guard maxFactor > boundaryFactor else { return 1.0 }
        return 0.3
    }

    private func factorToNorm(_ factor: CGFloat) -> CGFloat {
        let logMin = log(max(minFactor, 0.01))
        let logMax = log(max(maxFactor, 0.01))
        let logBound = log(max(boundaryFactor, 0.01))
        let logF = log(max(factor, 0.01))

        if logF <= logBound {
            return lowRatio * (logF - logMin) / (logBound - logMin)
        } else {
            return lowRatio + (1 - lowRatio) * (logF - logBound) / (logMax - logBound)
        }
    }

    private func normToFactor(_ norm: CGFloat) -> CGFloat {
        let logMin = log(max(minFactor, 0.01))
        let logMax = log(max(maxFactor, 0.01))
        let logBound = log(max(boundaryFactor, 0.01))

        let logF: CGFloat = if norm <= lowRatio {
            logMin + (norm / lowRatio) * (logBound - logMin)
        } else {
            logBound + ((norm - lowRatio) / (1 - lowRatio)) * (logMax - logBound)
        }
        return exp(min(max(logF, logMin), logMax))
    }

    private func logShiftedFactor(start: CGFloat, delta: CGFloat) -> CGFloat {
        let startNorm = factorToNorm(start)
        let targetNorm = startNorm + (-delta / 200.0)
        let clamped = min(max(targetNorm, 0), 1)
        return normToFactor(clamped)
    }

    @State private var lastTickHapticFactor: CGFloat?

    /// 모든 고정 배율(버튼 + 화각 포인트)에 스냅 + 햅틱
    private var allSnapFactors: [CGFloat] {
        Array(Set(availableFactors + allFixedFactors)).sorted()
    }

    private func snapFactor(_ raw: CGFloat) -> CGFloat {
        // 이미 스냅 중이면 탈출 임계값(8%)
        if let snapped = lastSnappedFactor {
            if abs(raw - snapped) / snapped <= 0.08 {
                return snapped
            }
            lastSnappedFactor = nil
            return raw
        }
        // 진입 (3%)
        for factor in allSnapFactors where abs(raw - factor) / factor <= 0.03 {
            lastSnappedFactor = factor
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return factor
        }
        // 드래그 중 틱 통과 햅틱 (0.1 단위)
        let displayVal = raw * zoomDivisor
        let tick01 = (displayVal * 10).rounded() / 10
        let tick01Factor = tick01 / zoomDivisor
        if abs(raw - tick01Factor) / max(tick01Factor, 0.01) < 0.01 {
            if lastTickHapticFactor != tick01Factor {
                lastTickHapticFactor = tick01Factor
                let is05 = abs(tick01.truncatingRemainder(dividingBy: 0.5)) < 0.05
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: is05 ? 0.6 : 0.3)
            }
        } else {
            lastTickHapticFactor = nil
        }
        return raw
    }
}

private struct ZoomButtonCell: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    private var fontSize: CGFloat {
        isSelected ? 13 : 12
    }

    private var dimension: CGFloat {
        isSelected ? 40 : 36
    }

    private var fillOpacity: Double {
        isSelected ? 0.65 : 0.45
    }

    private var strokeColor: Color {
        isSelected ? Color.yellow.opacity(0.55) : Color.white.opacity(0.12)
    }

    private var strokeWidth: CGFloat {
        isSelected ? 1.5 : 0.5
    }

    private var foreground: Color {
        isSelected ? .yellow : .white
    }

    var body: some View {
        Text(label)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground)
            .frame(width: dimension, height: dimension)
            .background(backgroundShape)
            .contentShape(Circle())
            .onTapGesture(perform: onTap)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
    }

    private var backgroundShape: some View {
        Circle()
            .fill(.black.opacity(fillOpacity))
            .overlay(Circle().strokeBorder(strokeColor, lineWidth: strokeWidth))
    }
}

private struct ZoomButtonRow: View {
    let availableFactors: [CGFloat]
    let currentFactor: CGFloat
    let zoomDivisor: CGFloat
    var onTap: ((CGFloat) -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(availableFactors.enumerated()), id: \.element) { index, factor in
                ZoomButtonCell(
                    label: isCurrentInRange(index: index) ? dynamicLabel() : fixedLabel(factor),
                    isSelected: isCurrentInRange(index: index),
                    onTap: { onTap?(factor) }
                )
            }
        }
    }

    /// currentFactor가 이 버튼의 구간에 속하는지 판단
    private func isCurrentInRange(index: Int) -> Bool {
        let factor = availableFactors[index]
        let lower: CGFloat = index > 0 ? midpoint(availableFactors[index - 1], factor) : 0
        let upper: CGFloat = index < availableFactors
            .count - 1 ? midpoint(factor, availableFactors[index + 1]) : CGFloat.infinity
        return currentFactor >= lower && currentFactor < upper
    }

    /// 두 factor 사이의 로그 중간점
    private func midpoint(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
        exp((log(max(lhs, 0.01)) + log(max(rhs, 0.01))) / 2)
    }

    /// 현재 배율로 동적 라벨 (1.3x 등)
    private func dynamicLabel() -> String {
        let value = currentFactor * zoomDivisor
        if abs(value - value.rounded()) < 0.05 {
            let intVal = Int(value.rounded())
            return intVal == 0 ? "0.5x" : "\(intVal)x"
        }
        return String(format: "%.1f", value)
    }

    /// 고정 라벨 (0.5x, 1x, 2x, 3x)
    private func fixedLabel(_ factor: CGFloat) -> String {
        let value = factor * zoomDivisor
        if value < 1.0 { return String(format: "%.1f", value) }
        if abs(value - value.rounded()) < 0.05 { return "\(Int(value.rounded()))x" }
        return String(format: "%.1f", value)
    }
}

private struct DialRenderer {
    let currentFactor: CGFloat
    let minFactor: CGFloat
    let maxFactor: CGFloat
    let availableFactors: [CGFloat]
    let focalLengthMap: [CGFloat: Int]
    let zoomDivisor: CGFloat
    let center: CGPoint
    let circleRadius: CGFloat

    private var boundary: CGFloat {
        availableFactors.last ?? maxFactor * 0.3
    }

    private var lowR: CGFloat {
        (maxFactor > boundary) ? 0.3 : 1.0
    }

    private var logMin: CGFloat {
        log(max(minFactor, 0.01))
    }

    private var logMax: CGFloat {
        log(max(maxFactor, 0.01))
    }

    private var logBound: CGFloat {
        log(max(boundary, 0.01))
    }

    func fToNorm(_ factor: CGFloat) -> CGFloat {
        let logF = log(max(factor, 0.01))
        if logF <= logBound {
            return lowR * (logF - logMin) / (logBound - logMin)
        } else {
            return lowR + (1 - lowR) * (logF - logBound) / (logMax - logBound)
        }
    }

    func tickAngle(_ factor: CGFloat, currentNorm: CGFloat) -> CGFloat {
        let norm = fToNorm(factor) - currentNorm
        return (270.0 + norm * 300.0) * .pi / 180.0
    }

    func drawBackground(context: inout GraphicsContext, canvasSize: CGSize) {
        let fullRect = CGRect(origin: .zero, size: canvasSize)
        let circlePath = Path(ellipseIn: CGRect(
            x: center.x - circleRadius,
            y: center.y - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        ))
        var mask = Path(fullRect)
        mask.addPath(circlePath)
        context.fill(mask, with: .color(.black.opacity(0.45)), style: FillStyle(eoFill: true))
        context.stroke(circlePath, with: .color(.white.opacity(0.3)), lineWidth: 1.5)
    }

    func drawMinorTicks(context: inout GraphicsContext, canvasSize: CGSize, currentNorm: CGFloat) {
        let displayMin = minFactor * zoomDivisor
        let displayMax = maxFactor * zoomDivisor
        let minorStep: CGFloat = 0.1
        let outerR = circleRadius + 3

        var displayVal = (displayMin / minorStep).rounded(.up) * minorStep
        while displayVal <= displayMax + minorStep * 0.5 {
            let internalFactor = displayVal / zoomDivisor
            let angle = tickAngle(internalFactor, currentNorm: currentNorm)
            let outerPt = CGPoint(x: center.x + cos(angle) * outerR, y: center.y + sin(angle) * outerR)

            guard outerPt.x >= -20 && outerPt.x <= canvasSize.width + 20 &&
                outerPt.y >= -20 && outerPt.y <= canvasSize.height + 20
            else {
                displayVal = ((displayVal + minorStep) * 100).rounded() / 100
                continue
            }

            let isMajor = availableFactors.contains { abs($0 - internalFactor) < minorStep * 0.4 }
            let displayRounded = (displayVal * 10).rounded() / 10
            let isMedium = !isMajor && abs(displayRounded.truncatingRemainder(dividingBy: 0.5)) < 0.05

            let tickLen: CGFloat = isMajor ? 12 : (isMedium ? 7 : 3)
            let tickAlpha: CGFloat = isMajor ? 0.9 : (isMedium ? 0.5 : 0.2)
            let tickWidth: CGFloat = isMajor ? 1.5 : (isMedium ? 0.8 : 0.5)

            let innerPt = CGPoint(
                x: center.x + cos(angle) * (outerR + tickLen),
                y: center.y + sin(angle) * (outerR + tickLen)
            )
            var tick = Path()
            tick.move(to: outerPt)
            tick.addLine(to: innerPt)
            context.stroke(tick, with: .color(.white.opacity(tickAlpha)), lineWidth: tickWidth)

            if isMajor {
                let labelR = outerR + tickLen + 12
                let labelPt = CGPoint(x: center.x + cos(angle) * labelR, y: center.y + sin(angle) * labelR)
                let near = abs(currentFactor - internalFactor) / max(internalFactor, 0.01) < 0.05
                context.draw(
                    Text(tickLabel(internalFactor))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(near ? Color.yellow : Color.white.opacity(0.8)),
                    at: labelPt,
                    anchor: .center
                )
            }

            displayVal = ((displayVal + minorStep) * 100).rounded() / 100
        }
    }

    func drawMajorTicks(context: inout GraphicsContext, canvasSize: CGSize, currentNorm: CGFloat) {
        let outerR = circleRadius + 3
        for factor in availableFactors {
            let angle = tickAngle(factor, currentNorm: currentNorm)
            let outerPt = CGPoint(x: center.x + cos(angle) * outerR, y: center.y + sin(angle) * outerR)

            guard outerPt.x >= -20, outerPt.x <= canvasSize.width + 20,
                  outerPt.y >= -20, outerPt.y <= canvasSize.height + 20 else { continue }

            let innerPt = CGPoint(
                x: center.x + cos(angle) * (outerR + 12),
                y: center.y + sin(angle) * (outerR + 12)
            )
            var tick = Path()
            tick.move(to: outerPt)
            tick.addLine(to: innerPt)
            context.stroke(tick, with: .color(.white.opacity(0.9)), lineWidth: 1.5)

            let labelR = outerR + 24
            let labelPt = CGPoint(x: center.x + cos(angle) * labelR, y: center.y + sin(angle) * labelR)
            let near = abs(currentFactor - factor) / max(factor, 0.01) < 0.05
            let displayV = factor * zoomDivisor

            context.draw(
                Text(zoomLabelText(displayV: displayV))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(near ? Color.yellow : Color.white.opacity(0.8)),
                at: labelPt,
                anchor: .center
            )

            if let mm = focalLengthMap.first(where: { abs($0.key - factor) < 0.05 })?.value {
                let mmPt = CGPoint(
                    x: center.x + cos(angle) * (labelR + 14),
                    y: center.y + sin(angle) * (labelR + 14)
                )
                context.draw(
                    Text("\(mm)mm")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(near ? Color.yellow.opacity(0.7) : Color.white.opacity(0.5)),
                    at: mmPt,
                    anchor: .center
                )
            }
        }
    }

    func drawIndicator(context: inout GraphicsContext) {
        let indAngle: CGFloat = 270 * .pi / 180
        let indOuter = CGPoint(
            x: center.x + cos(indAngle) * (circleRadius + 2),
            y: center.y + sin(indAngle) * (circleRadius + 2)
        )
        let indTip = CGPoint(
            x: center.x + cos(indAngle) * (circleRadius + 16),
            y: center.y + sin(indAngle) * (circleRadius + 16)
        )
        var indPath = Path()
        indPath.move(to: indOuter)
        indPath.addLine(to: indTip)
        context.stroke(indPath, with: .color(.yellow), lineWidth: 2.5)
    }

    func drawCenterLabel(context: inout GraphicsContext, label: String) {
        context.draw(
            Text(label)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.yellow),
            at: center,
            anchor: .center
        )
    }

    private func tickLabel(_ factor: CGFloat) -> String {
        let value = factor * zoomDivisor
        if value < 1.0 { return String(format: "%.1f", value) }
        if abs(value - value.rounded()) < 0.05 { return "\(Int(value.rounded()))x" }
        return String(format: "%.1f", value)
    }

    private func zoomLabelText(displayV: CGFloat) -> String {
        if displayV < 1.0 { return String(format: "%.1f", displayV) }
        if abs(displayV - displayV.rounded()) < 0.05 { return "\(Int(displayV.rounded()))x" }
        return String(format: "%.1f", displayV)
    }
}

/// 프리뷰 중앙에 원형 다이얼, 원 바깥 = 반투명 검정, 원 테두리 = 배율 틱마크
private struct CircleDialOverlay: View {
    let currentFactor: CGFloat
    let minFactor: CGFloat
    let maxFactor: CGFloat
    let availableFactors: [CGFloat]
    let focalLengthMap: [CGFloat: Int]
    let zoomDivisor: CGFloat
    let size: CGSize

    private var center: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private var circleRadius: CGFloat {
        min(size.width, size.height) * 0.38
    }

    private var currentDisplayLabel: String {
        let value = currentFactor * zoomDivisor
        if abs(value - value.rounded()) < 0.05 { return "\(Int(value.rounded()))x" }
        return String(format: "%.1fx", value)
    }

    var body: some View {
        let renderer = DialRenderer(
            currentFactor: currentFactor,
            minFactor: minFactor,
            maxFactor: maxFactor,
            availableFactors: availableFactors,
            focalLengthMap: focalLengthMap,
            zoomDivisor: zoomDivisor,
            center: center,
            circleRadius: circleRadius
        )
        let label = currentDisplayLabel
        Canvas { context, canvasSize in
            var ctx = context
            let currentNorm = renderer.fToNorm(currentFactor)
            renderer.drawBackground(context: &ctx, canvasSize: canvasSize)
            renderer.drawMinorTicks(context: &ctx, canvasSize: canvasSize, currentNorm: currentNorm)
            renderer.drawMajorTicks(context: &ctx, canvasSize: canvasSize, currentNorm: currentNorm)
            renderer.drawIndicator(context: &ctx)
            renderer.drawCenterLabel(context: &ctx, label: label)
        }
        .frame(width: size.width, height: size.height)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ZoomControlView(
            availableFactors: [0.5, 1.0, 2.0, 3.0],
            allFixedFactors: [0.5, 1.0, 2.0, 3.0],
            focalLengthMap: [0.5: 13, 1.0: 24, 2.0: 48, 3.0: 77],
            currentFactor: 2.0,
            minFactor: 0.5,
            maxFactor: 15.0,
            onZoomChanged: { _ in },
            onZoomDrag: { _ in }
        )
        .frame(width: 390, height: 520)
    }
}
