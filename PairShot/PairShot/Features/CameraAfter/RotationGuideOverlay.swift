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

    private static let captureAngleByExif: [CGImagePropertyOrientation: Int] = [
        .up: 0,
        .upMirrored: 0,
        .right: 90,
        .rightMirrored: 90,
        .down: 180,
        .downMirrored: 180,
        .left: 270,
        .leftMirrored: 270,
    ]

    private static let deviceAngleByOrientation: [UIDeviceOrientation: Int] = [
        .landscapeLeft: 0,
        .portrait: 90,
        .faceUp: 90,
        .faceDown: 90,
        .unknown: 90,
        .landscapeRight: 180,
        .portraitUpsideDown: 270,
    ]

    private static let directionByDelta: [Int: RotationGuideDirection] = [
        0: .upright,
        90: .right,
        -90: .left,
        180: .right,
        -180: .right,
    ]

    static func captureAngleDegrees(from exif: CGImagePropertyOrientation) -> Int {
        captureAngleByExif[exif] ?? 90
    }

    static func deviceAngleDegrees(from orientation: UIDeviceOrientation) -> Int {
        deviceAngleByOrientation[orientation] ?? 90
    }

    static func displayDelta(
        beforeExif: CGImagePropertyOrientation,
        orientation: UIDeviceOrientation
    ) -> Int {
        let captureAngle = captureAngleDegrees(from: beforeExif)
        let deviceAngle = deviceAngleDegrees(from: orientation)
        let raw = ((captureAngle - deviceAngle) % 360 + 360) % 360
        return raw > 180 ? raw - 360 : raw
    }

    static func direction(
        for orientation: UIDeviceOrientation,
        beforeExif: CGImagePropertyOrientation
    ) -> RotationGuideDirection {
        let delta = displayDelta(beforeExif: beforeExif, orientation: orientation)
        let result = directionByDelta[delta] ?? .upright
        let captureAngle = captureAngleDegrees(from: beforeExif)
        let deviceAngle = deviceAngleDegrees(from: orientation)
        logger
            .info(
                "[CAM-ROT-BRANCH] beforeExif=\(beforeExif.rawValue, privacy: .public), captureAngle=\(captureAngle, privacy: .public), deviceOrient=\(orientation.rawValue, privacy: .public), deviceAngle=\(deviceAngle, privacy: .public), displayDelta=\(delta, privacy: .public), direction=\(String(describing: result), privacy: .public)"
            )
        return result
    }
}

#Preview {
    ZStack {
        Color.appOnSurfaceVariant
        RotationGuideOverlay(direction: .left)
    }
}
