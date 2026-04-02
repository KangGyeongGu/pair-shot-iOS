import simd
import SwiftUI

struct SixDOFGuideView: View {
    let positionDelta: SIMD3<Float>
    let orientationDelta: SIMD3<Float>
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
            // delta = current - saved; delta > 0 → 현재가 오른쪽 → 왼쪽으로 이동해야 함
            if abs(positionDelta.x) > positionThreshold {
                directionArrow(
                    icon: positionDelta.x > 0 ? "arrow.left" : "arrow.right",
                    label: positionDelta.x > 0 ? "← 왼쪽" : "오른쪽 →",
                    distance: abs(positionDelta.x),
                    threshold: positionThreshold
                )
            }
            // delta > 0 → 현재가 위 → 아래로 이동해야 함
            if abs(positionDelta.y) > positionThreshold {
                directionArrow(
                    icon: positionDelta.y > 0 ? "arrow.down" : "arrow.up",
                    label: positionDelta.y > 0 ? "↓ 아래로" : "↑ 위로",
                    distance: abs(positionDelta.y),
                    threshold: positionThreshold
                )
            }
            // delta > 0 → 현재가 뒤 → 앞으로 이동해야 함
            if abs(positionDelta.z) > positionThreshold {
                directionArrow(
                    icon: positionDelta.z > 0 ? "arrow.down.backward" : "arrow.up.forward",
                    label: positionDelta.z > 0 ? "앞으로" : "뒤로",
                    distance: abs(positionDelta.z),
                    threshold: positionThreshold
                )
            }
        }
    }

    private var orientationGuideSection: some View {
        HStack(spacing: 16) {
            // pitch(x): delta > 0 → 현재가 더 위로 기울어짐 → 아래로 기울여야
            if abs(orientationDelta.x) > orientationThreshold {
                directionArrow(
                    icon: orientationDelta.x > 0 ? "iphone.gen3" : "iphone.gen3.radiowaves.left.and.right",
                    label: orientationDelta.x > 0 ? "아래로 기울여" : "위로 들어",
                    distance: abs(orientationDelta.x),
                    threshold: orientationThreshold
                )
            }
            // yaw(y): delta > 0 → 현재가 더 왼쪽 회전 → 오른쪽으로 돌아야
            if abs(orientationDelta.y) > orientationThreshold {
                directionArrow(
                    icon: orientationDelta.y > 0 ? "rotate.right" : "rotate.left",
                    label: orientationDelta.y > 0 ? "오른쪽 회전" : "왼쪽 회전",
                    distance: abs(orientationDelta.y),
                    threshold: orientationThreshold
                )
            }
            // roll(z): delta > 0 → 현재가 더 시계방향 → 반시계방향으로 돌려야
            if abs(orientationDelta.z) > orientationThreshold {
                directionArrow(
                    icon: "rotate.3d",
                    label: orientationDelta.z > 0 ? "반시계방향" : "시계방향",
                    distance: abs(orientationDelta.z),
                    threshold: orientationThreshold
                )
            }
        }
    }

    private func directionArrow(icon: String, label: String, distance: Float, threshold: Float) -> some View {
        let urgency = min(distance / (threshold * 5), 1.0)
        let color: Color = urgency < 0.3 ? .green : (urgency < 0.7 ? .yellow : .red)

        return VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
            Text(String(format: "%.0fcm", distance * 100))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
