import SwiftUI

struct CameraSettingsOverlayAlphaSlider: View {
    let alpha: Double
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(String(localized: "camera_settings_overlay_opacity"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                Spacer(minLength: 0)
                Text(percentText)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.white)
            }
            Slider(
                value: Binding(
                    get: { GhostOverlayMath.clamp(alpha) },
                    set: { onChange(GhostOverlayMath.clamp($0)) }
                ),
                in: GhostOverlayMath.alphaRange
            )
            .tint(Color.accentColor)
            .accessibilityLabel(String(localized: "camera_settings_overlay_opacity"))
            if alpha > 0.75 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(String(localized: "camera_settings_overlay_opacity_hint"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "camera_settings_overlay_opacity_hint"))
            }
        }
    }

    private var percentText: String {
        "\(Int((GhostOverlayMath.clamp(alpha) * 100).rounded()))%"
    }
}
