import SwiftUI

enum RotationGuideDirection {
    case upright
    case left
    case right
}

struct RotationGuideOverlay: View {
    enum RotationPhase: CaseIterable {
        case start
        case rotated
        case faded
    }

    let direction: RotationGuideDirection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if direction != .upright {
            VStack(spacing: AppSpacing.md) {
                iconView
                Text(label)
                    .font(.appBody)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 160, height: 160)
            .adaptiveGlass(
                in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                legacyFill: .black.opacity(0.6),
                kind: .regular,
            )
            .environment(\.colorScheme, .dark)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        let base = Image(systemName: "iphone")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(.white)
        if reduceMotion {
            base
        } else {
            base.phaseAnimator(RotationPhase.allCases) { content, phase in
                content
                    .rotationEffect(.degrees(phase == .start ? 0 : targetAngle))
                    .opacity(phase == .faded ? 0 : 1)
            } animation: { phase in
                switch phase {
                    case .start: .linear(duration: 0)
                    case .rotated: .easeInOut(duration: 1.2)
                    case .faded: .easeIn(duration: 0.4)
                }
            }
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

extension RotationGuideDirection {
    init(capture: CameraOrientation, device: CameraOrientation) {
        if capture == device {
            self = .upright
            return
        }
        let diff = (device.rawValue - capture.rawValue + 4) % 4
        switch diff {
            case 1: self = .left
            case 2: self = capture == .landscapeLeft ? .left : .right
            case 3: self = .right
            default: self = .upright
        }
    }
}

#Preview {
    ZStack {
        Color.appOnSurfaceVariant
        RotationGuideOverlay(direction: .left)
    }
}
