import simd
import SwiftUI

struct SixDOFGuideView: View {
    let positionDelta: SIMD3<Float>
    let yawDelta: Float
    let pitchDelta: Float
    let rollDelta: Float
    let positionThreshold: Float
    let orientationThreshold: Float
    let isPositionMatched: Bool
    let isOrientationMatched: Bool

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                lateralIndicator
                heightIndicator
                depthIndicator
                yawIndicator
                pitchIndicator
                rollIndicator
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private let ringSize: CGFloat = 36
    private let lineWidth: CGFloat = 2.0

    // 좌우: 테두리 좌/우 호가 강조
    private var lateralIndicator: some View {
        let val = positionDelta.x
        let matched = abs(val) <= positionThreshold
        return indicatorWrapper(label: "좌우", matched: matched) {
            if matched {
                checkmark
            } else {
                ZStack {
                    baseRing
                    let goLeft = val > 0
                    arcHighlight(
                        start: goLeft ? 0.5 : 0.0,
                        end: goLeft ? 0.85 : 0.35,
                        intensity: abs(val) / (positionThreshold * 5)
                    )
                    Image(systemName: goLeft ? "chevron.left" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // 높이: 테두리 상/하 호가 강조
    private var heightIndicator: some View {
        let val = positionDelta.y
        let matched = abs(val) <= positionThreshold
        return indicatorWrapper(label: "높이", matched: matched) {
            if matched {
                checkmark
            } else {
                ZStack {
                    baseRing
                    let goDown = val > 0
                    arcHighlight(
                        start: goDown ? 0.25 : 0.0,
                        end: goDown ? 0.6 : 0.1,
                        intensity: abs(val) / (positionThreshold * 5)
                    )
                    Image(systemName: goDown ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // 거리: 원이 펄스 애니메이션
    private var depthIndicator: some View {
        let val = positionDelta.z
        let matched = abs(val) <= positionThreshold
        return indicatorWrapper(label: "거리", matched: matched) {
            if matched {
                checkmark
            } else {
                ZStack {
                    baseRing
                    let norm = min(abs(val) / (positionThreshold * 5), 1.0)
                    Circle()
                        .strokeBorder(indicatorColor(norm).opacity(0.6), lineWidth: 1)
                        .frame(
                            width: ringSize * CGFloat(val > 0 ? 0.5 : 0.85),
                            height: ringSize * CGFloat(val > 0 ? 0.5 : 0.85)
                        )
                    Text(String(format: "%.0f", abs(val) * 100))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // 회전(yaw): 원 테두리 위에 dot이 회전
    private var yawIndicator: some View {
        let matched = abs(yawDelta) <= orientationThreshold
        return indicatorWrapper(label: "회전", matched: matched) {
            if matched {
                checkmark
            } else {
                ZStack {
                    baseRing
                    let angle = Angle(radians: Double(clamp(yawDelta, limit: .pi)))
                    let norm = min(abs(yawDelta) / (orientationThreshold * 5), 1.0)
                    Circle()
                        .fill(indicatorColor(norm))
                        .frame(width: 6, height: 6)
                        .offset(y: -ringSize / 2 + 2)
                        .rotationEffect(angle)
                    smallArrow(clockwise: yawDelta > 0)
                }
            }
        }
    }

    // 기울기(pitch): 원 안에 수평선이 상하로 기울어짐
    private var pitchIndicator: some View {
        let matched = abs(pitchDelta) <= orientationThreshold
        return indicatorWrapper(label: "기울기", matched: matched) {
            if matched {
                checkmark
            } else {
                let tilt = Double(clamp(pitchDelta, limit: .pi / 4)) * (180 / .pi)
                let norm = min(abs(pitchDelta) / (orientationThreshold * 5), 1.0)
                ZStack {
                    baseRing
                    RoundedRectangle(cornerRadius: 1)
                        .fill(indicatorColor(norm))
                        .frame(width: ringSize * 0.55, height: 2.5)
                        .rotationEffect(.degrees(tilt), anchor: .center)
                }
            }
        }
    }

    // 수평(roll): 원 안에 수평선이 좌우로 기울어짐
    private var rollIndicator: some View {
        let matched = abs(rollDelta) <= orientationThreshold
        return indicatorWrapper(label: "수평", matched: matched) {
            if matched {
                checkmark
            } else {
                let tilt = Double(clamp(rollDelta, limit: .pi / 4)) * (180 / .pi)
                let norm = min(abs(rollDelta) / (orientationThreshold * 5), 1.0)
                ZStack {
                    baseRing
                    HStack(spacing: 2) {
                        Circle().fill(indicatorColor(norm)).frame(width: 4, height: 4)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(indicatorColor(norm))
                            .frame(width: ringSize * 0.35, height: 2.5)
                    }
                    .rotationEffect(.degrees(tilt), anchor: .center)
                }
            }
        }
    }

    // --- 공용 컴포넌트 ---

    private var baseRing: some View {
        Circle()
            .strokeBorder(.white.opacity(0.25), lineWidth: lineWidth)
            .frame(width: ringSize, height: ringSize)
    }

    private var checkmark: some View {
        ZStack {
            Circle()
                .strokeBorder(.green, lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.green)
        }
    }

    private func arcHighlight(start: Double, end: Double, intensity: Float) -> some View {
        Circle()
            .trim(from: start, to: end)
            .stroke(indicatorColor(intensity), lineWidth: lineWidth + 1.5)
            .frame(width: ringSize, height: ringSize)
            .rotationEffect(.degrees(-90))
    }

    private func smallArrow(clockwise: Bool) -> some View {
        Image(systemName: clockwise ? "arrow.clockwise" : "arrow.counterclockwise")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white.opacity(0.7))
    }

    private func indicatorColor(_ normalizedValue: Float) -> Color {
        let v = min(normalizedValue, 1.0)
        if v < 0.3 { return .green }
        if v < 0.7 { return .yellow }
        return .red
    }

    private func indicatorWrapper(
        label: String,
        matched: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(spacing: 3) {
            content()
                .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7), value: matched)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(matched ? .green : .white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private func clamp(_ value: Float, limit: Float) -> Float {
        max(-limit, min(limit, value))
    }
}
