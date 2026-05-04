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

    static func direction(
        for orientation: UIDeviceOrientation,
        beforeExif: CGImagePropertyOrientation
    ) -> RotationGuideDirection {
        let beforeIsLandscape = switch beforeExif {
            case .up, .down, .upMirrored, .downMirrored:
                true

            case .left, .right, .leftMirrored, .rightMirrored:
                false

            @unknown default:
                false
        }
        let deviceIsLandscape = orientation.isLandscape
        let direction: RotationGuideDirection
        let branch: String
        if beforeIsLandscape == deviceIsLandscape {
            direction = .upright
            branch = "match-upright"
        } else if beforeIsLandscape {
            let isUpExif = beforeExif == .up || beforeExif == .upMirrored
            direction = isUpExif ? .left : .right
            branch = "before-landscape"
        } else {
            direction = orientation == .landscapeLeft ? .left : .right
            branch = "before-portrait"
        }
        logger
            .info(
                "[CAM-ROT-BRANCH] beforeExif=\(beforeExif.rawValue, privacy: .public), beforeIsLandscape=\(beforeIsLandscape, privacy: .public), deviceOrient=\(orientation.rawValue, privacy: .public), deviceIsLandscape=\(deviceIsLandscape, privacy: .public), branch=\(branch, privacy: .public), direction=\(String(describing: direction), privacy: .public)"
            )
        return direction
    }
}

#Preview {
    ZStack {
        Color.appOnSurfaceVariant
        RotationGuideOverlay(direction: .left)
    }
}
