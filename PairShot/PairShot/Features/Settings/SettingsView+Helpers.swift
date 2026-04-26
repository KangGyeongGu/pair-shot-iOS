import SwiftUI

/// Helpers extracted out of `SettingsView.swift` to keep the latter under
/// the 250-line cap surfaced by the P8b reviewer advisory.
///
/// Two surfaces:
/// - ``SettingsRow`` — the active-row label used by every NavigationLink
///   in the settings list (icon + title + secondary subtitle).
/// - ``DisabledSettingsRow`` — the greyed-out placeholder for sections
///   whose owning phase hasn't shipped yet. As of P8c only the
///   "내보내기" section uses it (export options live in the share sheet
///   itself).
///
/// `compositionSummary` was also moved onto ``AppSettings`` (see the
/// extension at the bottom) so SettingsView's body can pluck the string
/// straight from the environment without re-deriving it inline.
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

/// Greyed-out row used for sections whose owning phase hasn't shipped.
/// Marked with `.disabled(true)` so VoiceOver still announces it but
/// taps don't push a placeholder destination.
struct DisabledSettingsRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

extension AppSettings {
    /// Localised summary of the active capture defaults shown beneath
    /// the "촬영" row. Lives on `AppSettings` so the settings list can
    /// pluck the string without re-deriving it inline.
    var captureSummary: String {
        let quality = CaptureQualityPreset.nearest(to: jpegQuality)
        let prefix = FileNamePrefixValidator.sanitize(fileNamePrefix)
        if prefix.isEmpty {
            return String(format: String(localized: "품질 %@"), quality.label)
        }
        return String(format: String(localized: "품질 %@ · prefix \"%@\""), quality.label, prefix)
    }

    /// Localised summary of the active composition defaults shown
    /// beneath the "합성" row. Mirrors ``captureSummary``'s shape so
    /// the two rows have a consistent visual rhythm.
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
