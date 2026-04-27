import SwiftUI

struct WatermarkSettingsView: View {
    @Bindable var viewModel: WatermarkSettingsViewModel

    var body: some View {
        Form {
            basicSection
            if viewModel.settings.type == .text {
                textSection
            }
            previewSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "watermark_settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.settings) { _, _ in
            Task { await viewModel.saveSettings() }
        }
    }

    private var basicSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.isEnabled) {
                Label(
                    String(localized: "settings_item_watermark_use"),
                    systemImage: "signature"
                )
            }
            HStack {
                Text(String(localized: "watermark_field_type"))
                Spacer()
                Picker(String(localized: "watermark_field_type"), selection: $viewModel.settings.type) {
                    Text(verbatim: "TEXT")
                        .tag(WatermarkSettings.WatermarkType.text)
                    Text(verbatim: "LOGO")
                        .tag(WatermarkSettings.WatermarkType.logo)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        } header: {
            Text(String(localized: "watermark_section_basic"))
        } footer: {
            if viewModel.settings.type == .logo {
                Text(String(localized: "watermark_logo_unsupported_hint"))
            }
        }
    }

    private var textSection: some View {
        Section {
            WatermarkTextField(text: $viewModel.settings.text)
            WatermarkOpacitySlider(value: $viewModel.settings.opacity)
            WatermarkLineCountSlider(value: $viewModel.settings.lineCount)
            WatermarkRepeatSlider(value: $viewModel.settings.repeatCount)
        } header: {
            Text(String(localized: "watermark_section_text"))
        }
    }

    private var previewSection: some View {
        Section {
            WatermarkPreviewCard(settings: viewModel.settings)
                .frame(maxWidth: .infinity)
        } header: {
            Text(String(localized: "watermark_section_preview"))
        }
    }
}

private struct WatermarkTextField: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Text(String(localized: "watermark_field_text"))
            Spacer()
            TextField(
                String(localized: "watermark_field_text"),
                text: $text
            )
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.plain)
            .submitLabel(.done)
        }
    }
}

private struct WatermarkOpacitySlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_opacity"))
                Spacer()
                Text(verbatim: "\(Int((value * 100).rounded()))%")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: WatermarkSettings.opacityRange)
        }
    }
}

private struct WatermarkLineCountSlider: View {
    @Binding var value: Int

    private var doubleBinding: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { value = Int($0.rounded()) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_lines"))
                Spacer()
                Text(verbatim: "\(value)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: doubleBinding,
                in: Double(WatermarkSettings.lineCountRange.lowerBound)
                    ... Double(WatermarkSettings.lineCountRange.upperBound),
                step: 1
            )
        }
    }
}

private struct WatermarkRepeatSlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_repeat"))
                Spacer()
                Text(verbatim: String(format: "%.1fx", value))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $value,
                in: WatermarkSettings.repeatCountRange,
                step: 0.1
            )
        }
    }
}

private struct WatermarkPreviewCard: View {
    let settings: WatermarkSettings

    var body: some View {
        ZStack {
            Color.appLetterbox
            if settings.isEnabled, settings.type == .text, !settings.text.isEmpty {
                Text(settings.text)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(settings.opacity))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            } else {
                Text(String(localized: "watermark_preview_empty"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .frame(minHeight: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "watermark_preview_desc"))
    }
}

private struct WatermarkSettingsViewPreviewWrapper: View {
    @State private var viewModel = WatermarkSettingsViewModel(
        appSettingsRepo: UserDefaultsAppSettingsRepository(
            defaults: UserDefaults(suiteName: "preview-watermark") ?? .standard
        )
    )

    var body: some View {
        NavigationStack {
            WatermarkSettingsView(viewModel: viewModel)
        }
    }
}

#Preview {
    WatermarkSettingsViewPreviewWrapper()
}
