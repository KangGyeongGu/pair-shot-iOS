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
            .modifier(RotationGuideBackground())
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

private struct RotationGuideBackground: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(shape.fill(Color.black.opacity(0.6)))
        }
    }
}

enum RotationGuideResolver {
    static func direction(for orientation: UIDeviceOrientation) -> RotationGuideDirection {
        switch orientation {
            case .landscapeLeft: .right
            case .landscapeRight: .left
            default: .upright
        }
    }
}

#Preview {
    ZStack {
        Color.appOnSurfaceVariant
        RotationGuideOverlay(direction: .left)
    }
}
