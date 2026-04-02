import SwiftUI

enum GuidanceStage {
    case locating
    case positioning
    case aligning
}

struct SensorAlignment {
    static let pitchTolerance: Double = 0.0349
    static let rollTolerance: Double = 0.0349
    static let yawTolerance: Double = 0.0873

    static let positioningThreshold: Double = 0.1745
    static let aligningPitchRoll: Double = 0.0349
    static let aligningYaw: Double = 0.0873

    private static let weightPitch: Double = 1.0
    private static let weightRoll: Double = 1.0
    private static let weightYaw: Double = 0.5

    let deltaPitch: Double
    let deltaRoll: Double
    let deltaYaw: Double

    init(
        currentPitch: Double,
        currentRoll: Double,
        currentYaw: Double,
        targetPitch: Double,
        targetRoll: Double,
        targetYaw: Double
    ) {
        deltaPitch = currentPitch - targetPitch
        deltaRoll = currentRoll - targetRoll
        deltaYaw = currentYaw - targetYaw
    }

    var stage: GuidanceStage {
        if abs(deltaPitch) <= Self.aligningPitchRoll,
           abs(deltaRoll) <= Self.aligningPitchRoll,
           abs(deltaYaw) <= Self.aligningYaw
        {
            .aligning
        } else if abs(deltaPitch) <= Self.positioningThreshold,
                  abs(deltaRoll) <= Self.positioningThreshold,
                  abs(deltaYaw) <= Self.positioningThreshold
        {
            .positioning
        } else {
            .locating
        }
    }

    var isPositioning: Bool {
        stage == .positioning || stage == .aligning
    }

    var isAligned: Bool {
        abs(deltaPitch) <= Self.pitchTolerance &&
            abs(deltaRoll) <= Self.rollTolerance &&
            abs(deltaYaw) <= Self.yawTolerance
    }

    var alignmentScore: Double {
        let dp = deltaPitch / Self.pitchTolerance
        let dr = deltaRoll / Self.rollTolerance
        let dy = deltaYaw / Self.yawTolerance
        let weighted = Self.weightPitch * dp * dp +
            Self.weightRoll * dr * dr +
            Self.weightYaw * dy * dy
        return max(0.0, 1.0 - sqrt(weighted))
    }
}

struct SensorGuideView: View {
    let currentPitch: Double
    let currentRoll: Double
    let currentYaw: Double
    let targetPitch: Double
    let targetRoll: Double
    let targetYaw: Double

    private enum Constants {
        static let totalSize: CGFloat = 120
        static let sphereRadius: CGFloat = 34
        static let ringRadiusX: CGFloat = 54
        static let ringRadiusY: CGFloat = 14
        static let gridLines: Int = 5
        static let markerRadius: CGFloat = 5
    }

    private var alignment: SensorAlignment {
        SensorAlignment(
            currentPitch: currentPitch,
            currentRoll: currentRoll,
            currentYaw: currentYaw,
            targetPitch: targetPitch,
            targetRoll: targetRoll,
            targetYaw: targetYaw
        )
    }

    var deltaPitch: Double {
        alignment.deltaPitch
    }

    var deltaRoll: Double {
        alignment.deltaRoll
    }

    var deltaYaw: Double {
        alignment.deltaYaw
    }

    var isAligned: Bool {
        alignment.isAligned
    }

    var alignmentScore: Double {
        alignment.alignmentScore
    }

    private var guideColor: Color {
        alignment.stage == .aligning ? .green : .red
    }

    private var pitchFraction: CGFloat {
        CGFloat(max(-1.0, min(1.0, deltaPitch / (.pi / 4))))
    }

    private var rollFraction: CGFloat {
        CGFloat(max(-1.0, min(1.0, deltaRoll / (.pi / 4))))
    }

    private var yawAngle: Double {
        max(-.pi, min(.pi, deltaYaw * 3.0))
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                drawYawRing(context: context, center: center)
                drawSphere(context: context, center: center)
            }
            .frame(width: Constants.totalSize, height: Constants.totalSize)
        }
        .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: deltaPitch)
        .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: deltaRoll)
        .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: deltaYaw)
    }

    private func drawSphere(context: GraphicsContext, center: CGPoint) {
        let radius = Constants.sphereRadius
        // 기울기 방향으로 구체 중심 이동 (roll → X축, pitch → Y축)
        let shiftX = rollFraction * radius * 0.5
        let shiftY = pitchFraction * radius * 0.5
        let sphereCenter = CGPoint(x: center.x + shiftX, y: center.y + shiftY)

        // 구체 외곽선
        let outline = Path(ellipseIn: CGRect(
            x: sphereCenter.x - radius,
            y: sphereCenter.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.stroke(outline, with: .color(guideColor.opacity(0.85)), lineWidth: 1.5)

        // 위도선 (수평 타원): 기울기에 따라 압축
        let latCount = Constants.gridLines
        for idx in 1 ..< latCount {
            let fraction = CGFloat(idx) / CGFloat(latCount) // 0~1 (극점 제외)
            let normalized = fraction * 2 - 1 // -1 ~ 1
            // pitch 기울기에 따라 위도선 간격 왜곡
            let yOffset = normalized * radius * (1.0 - abs(pitchFraction) * 0.3)
            let latY = sphereCenter.y + yOffset
            guard abs(latY - sphereCenter.y) < radius else { continue }
            let halfW = sqrt(max(0, radius * radius - yOffset * yOffset))
            // roll이 있으면 타원 높이 압축
            let ellipseH = halfW * 0.35 * (1.0 - abs(rollFraction) * 0.5)
            let latPath = Path(ellipseIn: CGRect(
                x: sphereCenter.x - halfW,
                y: latY - ellipseH,
                width: halfW * 2,
                height: ellipseH * 2
            ))
            context.stroke(latPath, with: .color(guideColor.opacity(0.25)), lineWidth: 0.8)
        }

        // 경도선 (수직 타원): 기울기에 따라 압축
        let lonCount = Constants.gridLines
        for idx in 1 ..< lonCount {
            let fraction = CGFloat(idx) / CGFloat(lonCount)
            let normalized = fraction * 2 - 1 // -1 ~ 1
            let xOffset = normalized * radius * (1.0 - abs(rollFraction) * 0.3)
            let lonX = sphereCenter.x + xOffset
            guard abs(lonX - sphereCenter.x) < radius else { continue }
            let halfH = sqrt(max(0, radius * radius - xOffset * xOffset))
            let ellipseW = halfH * 0.35 * (1.0 - abs(pitchFraction) * 0.5)
            let lonPath = Path(ellipseIn: CGRect(
                x: lonX - ellipseW,
                y: sphereCenter.y - halfH,
                width: ellipseW * 2,
                height: halfH * 2
            ))
            context.stroke(lonPath, with: .color(guideColor.opacity(0.25)), lineWidth: 0.8)
        }

        // 중심 십자선
        let crossLen: CGFloat = 5
        var crossPath = Path()
        crossPath.move(to: CGPoint(x: sphereCenter.x - crossLen, y: sphereCenter.y))
        crossPath.addLine(to: CGPoint(x: sphereCenter.x + crossLen, y: sphereCenter.y))
        crossPath.move(to: CGPoint(x: sphereCenter.x, y: sphereCenter.y - crossLen))
        crossPath.addLine(to: CGPoint(x: sphereCenter.x, y: sphereCenter.y + crossLen))
        context.stroke(crossPath, with: .color(.white.opacity(0.5)), lineWidth: 1)
    }

    private func drawYawRing(context: GraphicsContext, center: CGPoint) {
        let ringRX = Constants.ringRadiusX
        let ringRY = Constants.ringRadiusY

        // 링 타원 (3D 원반처럼 보이도록 수평으로 납작)
        let ringPath = Path(ellipseIn: CGRect(
            x: center.x - ringRX,
            y: center.y - ringRY,
            width: ringRX * 2,
            height: ringRY * 2
        ))
        context.stroke(ringPath, with: .color(guideColor.opacity(0.4)), lineWidth: 1.2)

        // yaw 각도로 마커 위치 계산 (정렬 시 12시 방향)
        let angle = yawAngle - .pi / 2
        let markerX = center.x + ringRX * cos(angle)
        let markerY = center.y + ringRY * sin(angle)
        let markerR = Constants.markerRadius

        let markerPath = Path(ellipseIn: CGRect(
            x: markerX - markerR,
            y: markerY - markerR,
            width: markerR * 2,
            height: markerR * 2
        ))
        context.fill(markerPath, with: .color(guideColor))
        context.stroke(markerPath, with: .color(.white.opacity(0.6)), lineWidth: 1)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SensorGuideView(
            currentPitch: 0.02,
            currentRoll: 0.03,
            currentYaw: 0.05,
            targetPitch: 0.0,
            targetRoll: 0.0,
            targetYaw: 0.0
        )
    }
}
