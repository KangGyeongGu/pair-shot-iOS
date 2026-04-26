import SwiftUI

enum RotationGuideDirection {
    case upright
    case left
    case right
}

struct RotationGuideOverlay: View {
    let direction: RotationGuideDirection

    @State private var animateRotation: Bool = false

    var body: some View {
        if direction != .upright {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(animateRotation ? targetAngle : 0))
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: animateRotation
                    )
                Text(label)
                    .font(.body)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .onAppear { animateRotation = true }
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
                String(localized: "왼쪽으로 눕혀 주세요")

            case .right:
                String(localized: "오른쪽으로 눕혀 주세요")

            case .upright:
                ""
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
        Color.gray
        RotationGuideOverlay(direction: .left)
    }
}
