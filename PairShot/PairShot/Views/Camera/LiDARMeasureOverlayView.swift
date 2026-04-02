import SwiftUI

struct LiDARMeasureOverlayView: View {
    let startPoint: CGPoint?
    let endPoint: CGPoint?
    let distance: Float?

    var body: some View {
        ZStack {
            if let start = startPoint, let end = endPoint {
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(.yellow, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
            }

            if let start = startPoint {
                Circle()
                    .fill(.yellow)
                    .frame(width: 12, height: 12)
                    .position(start)
            }

            if let end = endPoint {
                Circle()
                    .fill(.yellow)
                    .frame(width: 12, height: 12)
                    .position(end)

                if let distance {
                    distanceLabel(distance: distance)
                        .position(
                            x: ((startPoint?.x ?? end.x) + end.x) / 2,
                            y: ((startPoint?.y ?? end.y) + end.y) / 2 - 24
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func distanceLabel(distance: Float) -> some View {
        HStack(spacing: 4) {
            if distance > 3.0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 10))
            }
            Text(formattedDistance(distance))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.7), in: Capsule())
    }

    private func formattedDistance(_ meters: Float) -> String {
        if meters < 1.0 {
            String(format: "%.0f cm", meters * 100)
        } else {
            String(format: "%.2f m", meters)
        }
    }
}
