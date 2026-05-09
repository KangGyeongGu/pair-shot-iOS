import SwiftUI

struct CameraSettingsOverlayChip: View {
    @Environment(AppEnvironment.self) private var env

    let systemImage: String
    let isOn: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: CameraSettingsOverlayMetrics.chipLabelSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: CameraSettingsOverlayMetrics.chipIconSize, weight: .semibold))
                    .foregroundStyle(isOn ? Color.black : Color.white)
                    .frame(
                        width: CameraSettingsOverlayMetrics.chipSize,
                        height: CameraSettingsOverlayMetrics.chipSize
                    )
                    .background(
                        Circle().fill(isOn ? Color.accentColor : Color.white.opacity(0.18))
                    )

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
            .accessibilityLabel(label)
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        }
        .buttonStyle(.plain)
    }

    private func handleTap() {
        env.hapticService.impact(.light)
        action()
    }
}
