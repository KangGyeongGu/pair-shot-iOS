import SwiftUI

struct CaptureSettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    @State private var prefixDraft: String = ""

    var body: some View {
        Form {
            qualitySection
            prefixSection
        }
        .navigationTitle(String(localized: "capture_settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prefixDraft = appSettings.fileNamePrefix
        }
    }

    private var qualitySection: some View {
        Section {
            Picker(String(localized: "capture_settings_export_quality_picker"), selection: qualityBinding) {
                ForEach(ExportQuality.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(String(localized: "capture_settings_export_quality_picker"))
        } footer: {
            Text(qualityFooter)
        }
    }

    private var qualityBinding: Binding<ExportQuality> {
        Binding(
            get: { appSettings.exportQuality },
            set: { appSettings.exportQuality = $0 },
        )
    }

    private var qualityFooter: String {
        let preset = appSettings.exportQuality
        let percent = Int((preset.compressionQuality * 100).rounded())
        return String(
            format: String(localized: "capture_settings_overlay_summary_template"),
            preset.label,
            percent,
        )
    }

    private var prefixSection: some View {
        Section {
            TextField(
                String(localized: "capture_settings_filename_prefix_placeholder"),
                text: $prefixDraft,
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .onChange(of: prefixDraft) { _, newValue in
                let cleaned = FileNamePrefixValidator.sanitize(newValue)
                if cleaned != newValue {
                    prefixDraft = cleaned
                }
                appSettings.fileNamePrefix = cleaned
            }
        } header: {
            Text(String(localized: "capture_settings_filename_prefix"))
        } footer: {
            Text(prefixFooter)
        }
    }

    private var prefixFooter: String {
        let safe = FileNamePrefixValidator.sanitize(prefixDraft)
        if safe.isEmpty {
            return String(localized: "capture_settings_filename_empty_hint")
        }
        return String(
            format: String(localized: "capture_settings_filename_format_template"),
            safe,
            FileNamePrefixValidator.maxLength,
        )
    }
}

private struct CaptureSettingsViewPreviewWrapper: View {
    var body: some View {
        NavigationStack {
            CaptureSettingsView()
        }
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview-capture") ?? .standard))
    }
}

#Preview {
    CaptureSettingsViewPreviewWrapper()
}
