import OSLog
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
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pairshot",
        category: "Camera"
    )

    static func displayDelta(
        captureAngleDegrees: Double,
        orientation: UIDeviceOrientation
    ) -> Int {
        let capture = ((Int(captureAngleDegrees.rounded()) % 360) + 360) % 360
        let device = deviceAngle(for: orientation)
        let mod = ((capture - device) % 360 + 360) % 360
        return mod > 180 ? mod - 360 : mod
    }

    static func direction(
        captureAngleDegrees: Double,
        orientation: UIDeviceOrientation
    ) -> RotationGuideDirection {
        let delta = displayDelta(captureAngleDegrees: captureAngleDegrees, orientation: orientation)
        let result: RotationGuideDirection = delta == 0 ? .upright : (delta > 0 ? .right : .left)
        logger
            .info(
                "[CAM-ROT-BRANCH] captureAngle=\(captureAngleDegrees, privacy: .public), deviceOrient=\(orientation.rawValue, privacy: .public), displayDelta=\(delta, privacy: .public), direction=\(String(describing: result), privacy: .public)"
            )
        return result
    }

    private static func deviceAngle(for orientation: UIDeviceOrientation) -> Int {
        switch orientation {
            case .landscapeLeft: 0
            case .landscapeRight: 180
            case .portraitUpsideDown: 270
            default: 90
        }
    }
}

#Preview {
    ZStack {
        Color.appOnSurfaceVariant
        RotationGuideOverlay(direction: .left)
    }
}
