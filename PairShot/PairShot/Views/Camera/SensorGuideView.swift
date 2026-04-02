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
        static let outerRadius: CGFloat = 44
        static let scale: CGFloat = 200
        static let dotRadius: CGFloat = 7
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

    private var indicatorColor: Color {
        isAligned ? .green : .red
    }

    private var dotOffset: CGSize {
        let clampedX = max(-Constants.outerRadius, min(
            Constants.outerRadius,
            CGFloat(deltaRoll) * Constants.scale
        ))
        let clampedY = max(-Constants.outerRadius, min(
            Constants.outerRadius,
            CGFloat(-deltaPitch) * Constants.scale
        ))
        return CGSize(width: clampedX, height: clampedY)
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let outerRadius = Constants.outerRadius

                let outerCircle = Path(ellipseIn: CGRect(
                    x: center.x - outerRadius,
                    y: center.y - outerRadius,
                    width: outerRadius * 2,
                    height: outerRadius * 2
                ))
                context.stroke(
                    outerCircle,
                    with: .color(indicatorColor.opacity(0.7)),
                    lineWidth: 1.5
                )

                let yawDelta = deltaYaw
                if abs(yawDelta) > 0.01 {
                    let arcRadius = outerRadius + 10
                    let sweepAngle = min(abs(yawDelta) / SensorAlignment.yawTolerance, 1.0) * .pi / 2
                    let startAngle = Angle(radians: -.pi / 2)
                    let endAngle = yawDelta > 0
                        ? Angle(radians: -.pi / 2 + sweepAngle)
                        : Angle(radians: -.pi / 2 - sweepAngle)
                    var arcPath = Path()
                    arcPath.addArc(
                        center: center,
                        radius: arcRadius,
                        startAngle: startAngle,
                        endAngle: endAngle,
                        clockwise: yawDelta < 0
                    )
                    context.stroke(
                        arcPath,
                        with: .color(indicatorColor.opacity(0.8)),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )

                    let arrowAngle = endAngle.radians
                    let arrowTip = CGPoint(
                        x: center.x + arcRadius * cos(arrowAngle),
                        y: center.y + arcRadius * sin(arrowAngle)
                    )
                    let tangentSign: Double = yawDelta > 0 ? 1.0 : -1.0
                    let tangent = CGPoint(
                        x: -sin(arrowAngle) * tangentSign,
                        y: cos(arrowAngle) * tangentSign
                    )
                    let arrowLen: CGFloat = 6
                    let perp = CGPoint(x: -tangent.y, y: tangent.x)
                    let p1 = CGPoint(
                        x: arrowTip.x - tangent.x * arrowLen + perp.x * arrowLen * 0.5,
                        y: arrowTip.y - tangent.y * arrowLen + perp.y * arrowLen * 0.5
                    )
                    let p2 = CGPoint(
                        x: arrowTip.x - tangent.x * arrowLen - perp.x * arrowLen * 0.5,
                        y: arrowTip.y - tangent.y * arrowLen - perp.y * arrowLen * 0.5
                    )
                    var arrowPath = Path()
                    arrowPath.move(to: p1)
                    arrowPath.addLine(to: arrowTip)
                    arrowPath.addLine(to: p2)
                    context.stroke(
                        arrowPath,
                        with: .color(indicatorColor.opacity(0.8)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }

                let crossLen: CGFloat = 6
                var crossPath = Path()
                crossPath.move(to: CGPoint(x: center.x - crossLen, y: center.y))
                crossPath.addLine(to: CGPoint(x: center.x + crossLen, y: center.y))
                crossPath.move(to: CGPoint(x: center.x, y: center.y - crossLen))
                crossPath.addLine(to: CGPoint(x: center.x, y: center.y + crossLen))
                context.stroke(
                    crossPath,
                    with: .color(.white.opacity(0.4)),
                    lineWidth: 1
                )
            }
            .frame(
                width: (Constants.outerRadius + 20) * 2,
                height: (Constants.outerRadius + 20) * 2
            )

            Circle()
                .fill(indicatorColor)
                .frame(width: Constants.dotRadius * 2, height: Constants.dotRadius * 2)
                .offset(dotOffset)
                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: dotOffset)
        }
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
