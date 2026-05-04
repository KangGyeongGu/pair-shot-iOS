import SwiftUI

struct HighlightableCard<Content: View>: View {
    let isHighlighted: Bool
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pulseOpacity: Double = 0.0

    var body: some View {
        content
            .listRowBackground(
                pulseOpacity > 0
                    ? Color.accentColor.opacity(pulseOpacity)
                    : Color(.secondarySystemGroupedBackground)
            )
            .onAppear {
                if isHighlighted { startPulse() }
            }
            .onChange(of: isHighlighted) { _, newValue in
                if newValue { startPulse() }
            }
    }

    private func startPulse() {
        if reduceMotion { return }
        pulseOpacity = 0
        withAnimation(.easeInOut(duration: 0.5).repeatCount(4, autoreverses: true)) {
            pulseOpacity = 0.3
        }
        withAnimation(.easeInOut(duration: 0.4).delay(2.0)) {
            pulseOpacity = 0
        }
    }
}
