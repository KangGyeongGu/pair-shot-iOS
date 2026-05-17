import SwiftUI

struct PhoneOrientationGuide: View {
    private static let iconSize: CGFloat = 40
    private static let frameHeight: CGFloat = 64
    private static let animationDuration: Double = 1.2

    let targetRotation: Angle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedRotation: Angle = .zero

    var body: some View {
        Image(systemName: "iphone.gen3")
            .font(.system(size: Self.iconSize, weight: .regular))
            .foregroundStyle(.primary)
            .rotationEffect(reduceMotion ? targetRotation : animatedRotation)
            .frame(height: Self.frameHeight)
            .onAppear { startAnimationIfNeeded() }
            .onChange(of: targetRotation) { _, _ in
                animatedRotation = .zero
                startAnimationIfNeeded()
            }
    }

    private func startAnimationIfNeeded() {
        guard !reduceMotion else { return }
        animatedRotation = .zero
        withAnimation(.easeInOut(duration: Self.animationDuration).repeatForever(autoreverses: true)) {
            animatedRotation = targetRotation
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
