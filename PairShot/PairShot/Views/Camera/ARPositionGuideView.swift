import SwiftUI

struct ARPositionGuideView: View {
    let positionDelta: SIMD3<Float>
    let threshold: Float
    let isPositionMatched: Bool

    private func arrowSize(for delta: Float) -> CGFloat {
        let clamped = min(abs(delta), threshold * 6)
        let normalized = clamped / (threshold * 6)
        return 18 + CGFloat(normalized) * 34
    }

    private func arrowOpacity(for delta: Float) -> Double {
        let ratio = min(abs(delta) / threshold, 1.0)
        return Double(ratio) * 0.85 + 0.15
    }

    private func arrowColor(for delta: Float) -> Color {
        abs(delta) < threshold * 2 ? .green : .red
    }

    private func isWithin(_ delta: Float) -> Bool {
        abs(delta) <= threshold
    }

    var body: some View {
        ZStack {
            if !isWithin(positionDelta.x) {
                let xSize = arrowSize(for: positionDelta.x)
                Image(systemName: positionDelta.x > 0 ? "arrow.right" : "arrow.left")
                    .font(.system(size: xSize, weight: .bold))
                    .foregroundStyle(arrowColor(for: positionDelta.x))
                    .opacity(arrowOpacity(for: positionDelta.x))
                    .offset(y: 0)
            }

            if !isWithin(positionDelta.y) {
                let ySize = arrowSize(for: positionDelta.y)
                Image(systemName: positionDelta.y > 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: ySize, weight: .bold))
                    .foregroundStyle(arrowColor(for: positionDelta.y))
                    .opacity(arrowOpacity(for: positionDelta.y))
                    .offset(x: 0)
            }

            if !isWithin(positionDelta.z) {
                let zSize = arrowSize(for: positionDelta.z)
                let zNear = positionDelta.z < 0
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: zSize * 0.8, weight: .bold))
                    .foregroundStyle(arrowColor(for: positionDelta.z))
                    .opacity(arrowOpacity(for: positionDelta.z))
                    .scaleEffect(zNear ? 1.0 : 0.6)
                    .offset(y: 52)
            }
        }
        .frame(width: 150, height: 150)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
    }
}
