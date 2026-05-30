import SwiftUI

struct WatermarkSettingsView: View {
    @Bindable var viewModel: WatermarkSettingsViewModel
    @Environment(AppSettings.self) private var appSettings
    @Environment(Membership.self) private var membership
    @Environment(AppEnvironment.self) private var env
    @State private var showPaywall: Bool = false

    var body: some View {
        @Bindable var bindableAppSettings = appSettings
        VStack(spacing: 0) {
            BannerAdSlot()

            Form {
                basicSection(bindable: $bindableAppSettings.watermarkEnabled)
                if viewModel.settings.type == .text || !membership.proIsActive {
                    textSection
                } else {
                    logoSection
                }
            }
            .listStyle(.insetGrouped)
            .paywallSheet(isPresented: $showPaywall)
        }
        .navigationTitle(String(localized: "watermark_settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.settings) { _, _ in
            Task { await viewModel.saveSettings() }
        }
    }

    private var textSection: some View {
        Section {
            WatermarkTextField(text: $viewModel.settings.text)
            WatermarkOpacitySlider(value: $viewModel.settings.opacity)
            WatermarkTextSizeSlider(value: $viewModel.settings.textSizeRatio)
            WatermarkLineCountSlider(value: $viewModel.settings.lineCount)
            WatermarkRepeatSlider(value: $viewModel.settings.repeatCount)
        } header: {
            Text(String(localized: "watermark_section_text"))
        } footer: {
            previewFooter
        }
    }

    private var logoSection: some View {
        Section {
            WatermarkLogoPickerRow(
                hasLogo: viewModel.hasLogo,
                fileName: $viewModel.settings.logoFileName,
                pickerItem: $viewModel.logoPickerItem,
                onClear: { viewModel.clearLogo() },
            )
            WatermarkLogoAlphaSlider(value: $viewModel.settings.logoAlpha)
            WatermarkLogoSizeSlider(value: $viewModel.settings.logoWidthRatio)
            WatermarkLogoPositionPicker(selection: $viewModel.settings.logoPosition)
        } header: {
            Text(String(localized: "watermark_section_logo"))
        } footer: {
            previewFooter
        }
    }

    private var previewFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "watermark_section_preview"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            WatermarkPreview(settings: viewModel.settings, logoData: viewModel.cachedLogoData)
        }
        .padding(.top, 8)
        .padding(.horizontal, -16)
    }

    private var typeSelector: some View {
        HStack(spacing: 8) {
            typeButton(label: "TEXT", value: .text, locked: false)
            typeButton(label: "LOGO", value: .logo, locked: !membership.proIsActive)
        }
    }

    private func basicSection(bindable: Binding<Bool>) -> some View {
        Section {
            Toggle(isOn: bindable) {
                Label(
                    String(localized: "settings_item_watermark_use"),
                    systemImage: "signature",
                )
            }
            HStack {
                Text(String(localized: "watermark_field_type"))
                Spacer()
                typeSelector
            }
        } header: {
            Text(String(localized: "watermark_section_basic"))
        }
    }

    private func typeButton(
        label: String,
        value: WatermarkSettings.WatermarkType,
        locked: Bool,
    ) -> some View {
        let isSelected = viewModel.settings.type == value
        return Button {
            if locked {
                env.snackbarQueue.enqueue(
                    .proFeatureGate,
                    debounceKey: "pro_gate_pro_feature",
                )
                showPaywall = true
            } else {
                viewModel.settings.type = value
            }
        } label: {
            HStack(spacing: 4) {
                Text(verbatim: label)
                    .font(.callout.weight(.semibold))
                if locked {
                    ProLockBadge()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12)),
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5),
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
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
                text: $text,
            )
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.plain)
            .submitLabel(.done)
        }
    }
}

private struct WatermarkSettingsViewPreviewWrapper: View {
    private static let previewDefaults: UserDefaults = .init(suiteName: "preview-watermark") ?? .standard

    @State private var viewModel = WatermarkSettingsViewModel(
        appSettingsRepo: UserDefaultsAppSettingsRepository(defaults: previewDefaults),
        appSettings: AppSettings(defaults: previewDefaults),
    )

    var body: some View {
        NavigationStack {
            WatermarkSettingsView(viewModel: viewModel)
        }
        .environment(AppSettings(defaults: Self.previewDefaults))
    }
}

#Preview {
    WatermarkSettingsViewPreviewWrapper()
}
