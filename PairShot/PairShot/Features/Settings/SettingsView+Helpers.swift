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
            return String(format: String(localized: "품질 %@"), quality.label)
        }
        return String(format: String(localized: "품질 %@ · prefix \"%@\""), quality.label, prefix)
    }

    var compositionSummary: String {
        let alphaPct = Int((CompositionDefaults.clampAlpha(defaultOverlayAlpha) * 100).rounded())
        let layoutLabel = defaultCompositeLayout.label
        let watermark = watermarkEnabled
            ? String(localized: "워터마크 켜짐")
            : String(localized: "워터마크 꺼짐")
        return String(
            format: String(localized: "투명도 %d%% · %@ · %@"),
            alphaPct,
            layoutLabel,
            watermark
        )
    }
}
