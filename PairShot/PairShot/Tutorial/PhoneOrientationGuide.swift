import SwiftUI

struct PhoneOrientationGuide: View {
    enum RotationPhase: CaseIterable {
        case start
        case rotated
        case faded
    }

    private static let iconSize: CGFloat = 40
    private static let frameHeight: CGFloat = 64

    let targetRotation: Angle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let base = Image(systemName: "iphone.gen3")
            .font(.system(size: Self.iconSize, weight: .regular))
            .foregroundStyle(.primary)
            .frame(height: Self.frameHeight)
        if reduceMotion {
            base.rotationEffect(targetRotation)
        } else {
            base.phaseAnimator(RotationPhase.allCases) { content, phase in
                content
                    .rotationEffect(phase == .start ? .zero : targetRotation)
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

    static func targetRotation(for step: TutorialStep) -> Angle? {
        switch step {
            case .captureGuidePortrait: .degrees(5)
            case .captureGuideLeft: .degrees(-90)
            case .captureGuideRight: .degrees(90)
            default: nil
        }
    }
}
