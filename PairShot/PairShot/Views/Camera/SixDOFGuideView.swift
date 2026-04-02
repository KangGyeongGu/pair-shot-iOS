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
            if abs(positionDelta.x) > positionThreshold {
                directionArrow(
                    icon: positionDelta.x > 0 ? "arrow.left" : "arrow.right",
                    label: positionDelta.x > 0 ? "← 왼쪽" : "오른쪽 →",
                    distance: abs(positionDelta.x),
                    threshold: positionThreshold
                )
            }
            if abs(positionDelta.y) > positionThreshold {
                directionArrow(
                    icon: positionDelta.y > 0 ? "arrow.down" : "arrow.up",
                    label: positionDelta.y > 0 ? "↓ 아래로" : "↑ 위로",
                    distance: abs(positionDelta.y),
                    threshold: positionThreshold
                )
            }
            if abs(positionDelta.z) > positionThreshold {
                directionArrow(
                    icon: positionDelta.z > 0 ? "arrow.up.forward" : "arrow.down.backward",
                    label: positionDelta.z > 0 ? "뒤로" : "앞으로",
                    distance: abs(positionDelta.z),
                    threshold: positionThreshold
                )
            }
        }
    }

    private var orientationGuideSection: some View {
        HStack(spacing: 16) {
            if abs(orientationDelta.x) > orientationThreshold {
                directionArrow(
                    icon: orientationDelta.x > 0 ? "iphone.gen3.radiowaves.left.and.right" : "iphone.gen3",
                    label: orientationDelta.x > 0 ? "아래로 기울여" : "위로 들어",
                    distance: abs(orientationDelta.x),
                    threshold: orientationThreshold
                )
            }
            if abs(orientationDelta.y) > orientationThreshold {
                directionArrow(
                    icon: orientationDelta.y > 0 ? "rotate.left" : "rotate.right",
                    label: orientationDelta.y > 0 ? "왼쪽 회전" : "오른쪽 회전",
                    distance: abs(orientationDelta.y),
                    threshold: orientationThreshold
                )
            }
            if abs(orientationDelta.z) > orientationThreshold {
                directionArrow(
                    icon: "rotate.3d",
                    label: orientationDelta.z > 0 ? "시계방향" : "반시계방향",
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
