import SwiftUI

enum RotationGuideDirection {
    case upright
    case left
    case right
}

struct RotationGuideOverlay: View {
    let direction: RotationGuideDirection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animateRotation: Bool = false

    var body: some View {
        if direction != .upright {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: symbolName)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(animateRotation ? targetAngle : 0))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: animateRotation
                    )
                Text(label)
                    .font(.appBody)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .adaptiveGlass(
                in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                kind: .regular,
                legacyFill: .black.opacity(0.6)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .onAppear {
                if !reduceMotion { animateRotation = true }
            }
        }
    }

    private var symbolName: String {
        switch direction {
            case .left: "arrow.counterclockwise"
            case .right: "arrow.clockwise"
            case .upright: ""
        }
    }

    private var targetAngle: Double {
        switch direction {
            case .left: -90
            case .right: 90
            case .upright: 0
        }
    }

    private var label: String {
        switch direction {
            case .left:
                String(localized: "camera_hint_rotate_left_message")

            case .right:
                String(localized: "camera_hint_rotate_right_message")

            case .upright:
                ""
        }
    }
}

enum RotationGuideResolver {
    static func direction(
        captureAngleDegrees: Double,
        deviceAngleDegrees: Double
    ) -> RotationGuideDirection {
        if orientationBucket(captureAngleDegrees) == orientationBucket(deviceAngleDegrees) {
            return .upright
        }
        let raw = (captureAngleDegrees - deviceAngleDegrees).truncatingRemainder(dividingBy: 360)
        let positive = (raw + 360).truncatingRemainder(dividingBy: 360)
        let delta = positive > 180 ? positive - 360 : positive
        return delta > 0 ? .right : .left
    }

    private static func orientationBucket(_ angle: Double) -> Int {
        let normalized = ((angle.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        return Int(((normalized + 45) / 90).rounded(.down)) % 4
    }
}

#Preview {
    ZStack {
        Color.appOnSurfaceVariant
        RotationGuideOverlay(direction: .left)
    }
}
