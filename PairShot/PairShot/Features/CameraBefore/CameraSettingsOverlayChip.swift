import SwiftUI

struct CameraSettingsOverlayChip: View {
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
                        Circle().fill(isOn ? Color.appBrandPrimary : Color.white.opacity(0.18))
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
        HapticService.shared.impact(.light)
        action()
    }
}
