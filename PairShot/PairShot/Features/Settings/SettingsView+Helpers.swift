import SwiftUI

struct SettingsRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
        }
        .contentShape(Rectangle())
    }
}

extension AppSettings {
    var captureSummary: String {
        let quality = CaptureQualityPreset.nearest(to: jpegQuality)
        let prefix = FileNamePrefixValidator.sanitize(fileNamePrefix)
        if prefix.isEmpty {
            return String(format: String(localized: "settings_summary_quality_template"), quality.label)
        }
        return String(format: String(localized: "settings_summary_quality_prefix_template"), quality.label, prefix)
    }

    var compositionSummary: String {
        let alphaPct = Int((CompositionDefaults.clampAlpha(defaultOverlayAlpha) * 100).rounded())
        let layoutLabel = defaultCompositeLayout.label
        let watermark = watermarkEnabled
            ? String(localized: "settings_summary_watermark_on")
            : String(localized: "settings_summary_watermark_off")
        return String(
            format: String(localized: "settings_summary_overlay_template"),
            alphaPct,
            layoutLabel,
            watermark
        )
    }
}
