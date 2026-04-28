import SwiftUI

struct CameraSettingsOverlayChrome<Content: View>: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(CameraSettingsOverlayMetrics.dimOpacity)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)
                .accessibilityHidden(true)

            panel
                .padding(.horizontal, AppSpacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
    }

    private var panel: some View {
        let panelShape = RoundedRectangle(
            cornerRadius: CameraSettingsOverlayMetrics.panelCornerRadius,
            style: .continuous
        )
        return content
            .padding(CameraSettingsOverlayMetrics.panelPadding)
            .frame(maxWidth: CameraSettingsOverlayMetrics.panelMaxWidth)
            .adaptiveGlass(in: panelShape)
            .clipShape(panelShape)
            .overlay(
                panelShape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 24, y: 8)
            .accessibilityAddTraits(.isModal)
    }

    private func dismiss() {
        HapticService.shared.impact(.light)
        isPresented = false
    }
}
