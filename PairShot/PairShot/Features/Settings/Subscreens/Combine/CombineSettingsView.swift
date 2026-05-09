import SwiftUI

struct CombineSettingsView: View {
    @Bindable var viewModel: CombineSettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            BannerAdSlot()

            Form {
                directionSection
                borderSection
                labelSection
                if viewModel.settings.label.isEnabled {
                    labelModeSection
                    labelBackgroundSection
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(String(localized: "export_settings_section_combine"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.settings) { _, _ in
            Task { await viewModel.saveSettings() }
        }
    }

    private var previewFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "combine_section_preview"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            CombinePreviewCard(settings: viewModel.settings)
        }
        .padding(.top, 8)
        .padding(.horizontal, -16)
    }

    private var directionSection: some View {
        Section {
            Picker(String(localized: "combine_field_direction"), selection: $viewModel.settings.direction) {
                Text(String(localized: "combine_direction_horizontal_full")).tag(CombineSettings.Direction.horizontal)
                Text(String(localized: "combine_direction_vertical_full")).tag(CombineSettings.Direction.vertical)
            }
            .pickerStyle(.segmented)
        } header: {
            Text(String(localized: "combine_field_alignment"))
        }
    }

    private var borderSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.border.isEnabled) {
                Label(String(localized: "combine_item_border_use"), systemImage: "square.dashed")
            }
            if viewModel.settings.border.isEnabled {
                CombineSliderRow(
                    title: String(localized: "combine_field_thickness"),
                    value: $viewModel.settings.border.thickness,
                    range: CombineSettings.borderThicknessRange,
                    step: 1,
                    valueLabel: "\(Int(viewModel.settings.border.thickness))pt"
                )
                ColorPicker(
                    String(localized: "combine_field_color"),
                    selection: borderColorBinding,
                    supportsOpacity: false
                )
            }
        } header: {
            Text(String(localized: "combine_section_border"))
        }
    }

    private var labelSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.label.isEnabled) {
                Label(String(localized: "combine_item_label_use"), systemImage: "textformat")
            }
            if viewModel.settings.label.isEnabled {
                CombineLabelTextField(
                    title: String(localized: "combine_field_label_before"),
                    text: $viewModel.settings.label.beforeText
                )
                CombineLabelTextField(
                    title: String(localized: "combine_field_label_after"),
                    text: $viewModel.settings.label.afterText
                )
                CombineSliderRow(
                    title: String(localized: "combine_field_text_size"),
                    value: $viewModel.settings.label.textSizePercent,
                    range: CombineSettings.labelTextSizeRange,
                    step: 1,
                    valueLabel: "\(Int(viewModel.settings.label.textSizePercent))%"
                )
                ColorPicker(
                    String(localized: "combine_field_text_color"),
                    selection: labelTextColorBinding,
                    supportsOpacity: false
                )
            }
        } header: {
            Text(String(localized: "combine_section_label"))
        } footer: {
            if !viewModel.settings.label.isEnabled {
                previewFooter
            }
        }
    }

    private var labelModeSection: some View {
        Section {
            Picker(String(localized: "combine_field_mode"), selection: $viewModel.settings.labelMode) {
                Text(String(localized: "combine_label_mode_full_width")).tag(CombineSettings.LabelMode.fullWidth)
                Text(String(localized: "combine_label_mode_free")).tag(CombineSettings.LabelMode.free)
            }
            .pickerStyle(.segmented)

            if viewModel.settings.labelMode == .fullWidth {
                Picker(String(localized: "combine_field_position"), selection: $viewModel.settings.fullWidthVertical) {
                    Text(String(localized: "combine_position_top")).tag(CombineSettings.LabelPosition.Vertical.top)
                    Text(String(localized: "combine_position_bottom"))
                        .tag(CombineSettings.LabelPosition.Vertical.bottom)
                }
                .pickerStyle(.segmented)
            } else {
                CombinePositionPicker3x3(
                    label: String(localized: "combine_field_position_before"),
                    selection: $viewModel.settings.beforePosition
                )
                CombinePositionPicker3x3(
                    label: String(localized: "combine_field_position_after"),
                    selection: $viewModel.settings.afterPosition
                )
            }
        } header: {
            Text(String(localized: "combine_section_label_mode"))
        }
    }

    private var labelBackgroundSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.labelBackground.isEnabled) {
                Label(String(localized: "combine_item_background_use"), systemImage: "rectangle.fill")
            }
            if viewModel.settings.labelBackground.isEnabled {
                Toggle(isOn: $viewModel.settings.labelBackground.matchBorderColor) {
                    Text(String(localized: "combine_dialog_match_border_color"))
                }
                if !viewModel.settings.labelBackground.matchBorderColor {
                    ColorPicker(
                        String(localized: "combine_field_color"),
                        selection: labelBackgroundColorBinding,
                        supportsOpacity: false
                    )
                }
                CombineSliderRow(
                    title: String(localized: "combine_field_opacity"),
                    value: $viewModel.settings.labelBackground.opacity,
                    range: CombineSettings.labelBackgroundOpacityRange,
                    step: nil,
                    valueLabel: "\(Int((viewModel.settings.labelBackground.opacity * 100).rounded()))%"
                )
                if viewModel.settings.labelMode == .free {
                    CombineSliderRow(
                        title: String(localized: "combine_field_curvature"),
                        value: $viewModel.settings.labelBackground.cornerRadius,
                        range: CombineSettings.labelBackgroundCornerRadiusRange,
                        step: 1,
                        valueLabel: "\(Int(viewModel.settings.labelBackground.cornerRadius))pt"
                    )
                }
            }
        } header: {
            Text(String(localized: "combine_section_label_background"))
        } footer: {
            previewFooter
        }
    }

    private var borderColorBinding: Binding<Color> {
        Binding(
            get: { Color(rgba: viewModel.settings.border.color) },
            set: { viewModel.settings.border.color = ColorRGBA(color: $0) }
        )
    }

    private var labelTextColorBinding: Binding<Color> {
        Binding(
            get: { Color(rgba: viewModel.settings.label.textColor) },
            set: { viewModel.settings.label.textColor = ColorRGBA(color: $0) }
        )
    }

    private var labelBackgroundColorBinding: Binding<Color> {
        Binding(
            get: { Color(rgba: viewModel.settings.labelBackground.color) },
            set: { viewModel.settings.labelBackground.color = ColorRGBA(color: $0) }
        )
    }
}

private struct CombineLabelTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, text: $text)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                .submitLabel(.done)
        }
    }
}

private struct CombineSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let valueLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(valueLabel)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
        }
    }
}

private struct CombineSettingsViewPreviewWrapper: View {
    private static let previewDefaults: UserDefaults = .init(suiteName: "preview-combine") ?? .standard

    @State private var viewModel = CombineSettingsViewModel(
        appSettingsRepo: UserDefaultsAppSettingsRepository(defaults: previewDefaults),
        appSettings: AppSettings(defaults: previewDefaults)
    )

    var body: some View {
        NavigationStack {
            CombineSettingsView(viewModel: viewModel)
        }
    }
}

#Preview {
    CombineSettingsViewPreviewWrapper()
}
