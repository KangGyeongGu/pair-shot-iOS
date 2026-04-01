import CoreMotion
import SwiftUI

struct LevelIndicatorView: View {
    let previewWidth: CGFloat

    @State private var tilt: Double = 0
    @State private var isLevel = false
    private let motionManager = CMMotionManager()
    private let threshold = 1.0

    /// 중앙 격자 1칸 너비
    private var gridWidth: CGFloat {
        previewWidth / 3
    }

    /// 고정 바 길이 = 격자 1칸의 1/6
    private var fixedBarWidth: CGFloat {
        gridWidth / 6
    }

    var body: some View {
        ZStack {
            // 좌측 고정 바
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: fixedBarWidth, height: 1)
                .offset(x: -(gridWidth / 2 + fixedBarWidth / 2 + 2))

            // 우측 고정 바
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: fixedBarWidth, height: 1)
                .offset(x: gridWidth / 2 + fixedBarWidth / 2 + 2)

            // 중앙 수평계 (기울기에 따라 회전)
            Rectangle()
                .fill(isLevel ? Color.yellow : Color.white.opacity(0.6))
                .frame(width: gridWidth, height: isLevel ? 1.5 : 1)
                .rotationEffect(.degrees(tilt))
        }
        .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: tilt)
        .animation(.easeOut(duration: 0.15), value: isLevel)
        .onAppear { startMotion() }
        .onDisappear { motionManager.stopDeviceMotionUpdates() }
    }

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let gravity = motion?.gravity else { return }
            let degrees = asin(min(max(gravity.x, -1), 1)) * 180.0 / .pi
            tilt = degrees
            isLevel = abs(degrees) < threshold
        }
    }
}
