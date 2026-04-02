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
        VStack(spacing: 12) {
            if !isPositionMatched {
                positionGuideSection
            }

            if !isOrientationMatched {
                orientationGuideSection
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 20)
    }

    private var positionGuideSection: some View {
        HStack(spacing: 16) {
            if abs(positionDelta.x) > positionThreshold {
                directionArrow(
                    icon: positionDelta.x > 0 ? "arrow.left" : "arrow.right",
                    label: positionDelta.x > 0 ? "← 왼쪽" : "오른쪽 →",
                    value: abs(positionDelta.x),
                    threshold: positionThreshold,
                    isAngle: false
                )
            }
            if abs(positionDelta.y) > positionThreshold {
                directionArrow(
                    icon: positionDelta.y > 0 ? "arrow.down" : "arrow.up",
                    label: positionDelta.y > 0 ? "↓ 아래로" : "↑ 위로",
                    value: abs(positionDelta.y),
                    threshold: positionThreshold,
                    isAngle: false
                )
            }
            if abs(positionDelta.z) > positionThreshold {
                directionArrow(
                    icon: positionDelta.z > 0 ? "arrow.up.forward" : "arrow.down.backward",
                    label: positionDelta.z > 0 ? "가까이" : "멀리",
                    value: abs(positionDelta.z),
                    threshold: positionThreshold,
                    isAngle: false
                )
            }
        }
    }

    private var orientationGuideSection: some View {
        HStack(spacing: 16) {
            // yawDelta > 0: 현재가 왼쪽으로 회전된 상태 → 오른쪽으로 돌아야
            if abs(yawDelta) > orientationThreshold {
                directionArrow(
                    icon: yawDelta > 0 ? "rotate.right" : "rotate.left",
                    label: yawDelta > 0 ? "오른쪽 회전" : "왼쪽 회전",
                    value: abs(yawDelta),
                    threshold: orientationThreshold,
                    isAngle: true
                )
            }
            // pitchDelta > 0: 현재가 더 위를 바라봄 → 아래로 기울여야
            if abs(pitchDelta) > orientationThreshold {
                directionArrow(
                    icon: pitchDelta > 0 ? "iphone.gen3" : "iphone.gen3.radiowaves.left.and.right",
                    label: pitchDelta > 0 ? "아래로 기울여" : "위로 들어",
                    value: abs(pitchDelta),
                    threshold: orientationThreshold,
                    isAngle: true
                )
            }
            // rollDelta > 0: 시계방향으로 기울어짐 → 반시계방향으로
            if abs(rollDelta) > orientationThreshold {
                directionArrow(
                    icon: "rotate.3d",
                    label: rollDelta > 0 ? "반시계방향" : "시계방향",
                    value: abs(rollDelta),
                    threshold: orientationThreshold,
                    isAngle: true
                )
            }
        }
    }

    private func directionArrow(
        icon: String,
        label: String,
        value: Float,
        threshold: Float,
        isAngle: Bool
    ) -> some View {
        let urgency = min(value / (threshold * 5), 1.0)
        let color: Color = urgency < 0.3 ? .green : (urgency < 0.7 ? .yellow : .red)
        let displayText = isAngle
            ? String(format: "%.0f°", value * 180 / .pi)
            : String(format: "%.0fcm", value * 100)

        return VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
            Text(displayText)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
