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
        Task { @MainActor in
            for _ in 0 ..< 2 {
                withAnimation(.easeInOut(duration: 0.6)) {
                    pulseOpacity = 0.3
                }
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.easeInOut(duration: 0.4)) {
                    pulseOpacity = 0.0
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }
}
