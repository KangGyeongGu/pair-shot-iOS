import SwiftUI

struct CombineSettingsView: View {
    @Bindable var viewModel: CombineSettingsViewModel

    var body: some View {
        Form {
            directionSection
            borderSection
            labelSection
            if viewModel.settings.label.isEnabled {
                labelModeSection
                labelBackgroundSection
            }
            previewSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "합성 설정"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.settings) { _, _ in
            Task { await viewModel.saveSettings() }
        }
    }

    private var directionSection: some View {
        Section {
            Picker(String(localized: "방향"), selection: $viewModel.settings.direction) {
                Text(String(localized: "가로")).tag(CombineSettings.Direction.horizontal)
                Text(String(localized: "세로")).tag(CombineSettings.Direction.vertical)
            }
            .pickerStyle(.segmented)
        } header: {
            Text(String(localized: "정렬"))
        }
    }

    private var borderSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.border.isEnabled) {
                Label(String(localized: "테두리 사용"), systemImage: "square.dashed")
            }
            if viewModel.settings.border.isEnabled {
                CombineSliderRow(
                    title: String(localized: "두께"),
                    value: $viewModel.settings.border.thickness,
                    range: CombineSettings.borderThicknessRange,
                    step: 1,
                    valueLabel: "\(Int(viewModel.settings.border.thickness))pt"
                )
                ColorPicker(
                    String(localized: "색상"),
                    selection: borderColorBinding,
                    supportsOpacity: false
                )
            }
        } header: {
            Text(String(localized: "테두리"))
        }
    }

    private var labelSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.label.isEnabled) {
                Label(String(localized: "레이블 사용"), systemImage: "textformat")
            }
            if viewModel.settings.label.isEnabled {
                CombineLabelTextField(
                    title: String(localized: "Before 텍스트"),
                    text: $viewModel.settings.label.beforeText
                )
                CombineLabelTextField(
                    title: String(localized: "After 텍스트"),
                    text: $viewModel.settings.label.afterText
                )
                CombineSliderRow(
                    title: String(localized: "텍스트 크기"),
                    value: $viewModel.settings.label.textSizePercent,
                    range: CombineSettings.labelTextSizeRange,
                    step: 1,
                    valueLabel: "\(Int(viewModel.settings.label.textSizePercent))%"
                )
                ColorPicker(
                    String(localized: "텍스트 색상"),
                    selection: labelTextColorBinding,
                    supportsOpacity: false
                )
            }
        } header: {
            Text(String(localized: "레이블"))
        }
    }

    private var labelModeSection: some View {
        Section {
            Picker(String(localized: "모드"), selection: $viewModel.settings.labelMode) {
                Text(String(localized: "전체너비")).tag(CombineSettings.LabelMode.fullWidth)
                Text(String(localized: "자유")).tag(CombineSettings.LabelMode.free)
            }
            .pickerStyle(.segmented)

            if viewModel.settings.labelMode == .fullWidth {
                Picker(String(localized: "위치"), selection: $viewModel.settings.fullWidthVertical) {
                    Text(String(localized: "상단")).tag(CombineSettings.LabelPosition.Vertical.top)
                    Text(String(localized: "하단")).tag(CombineSettings.LabelPosition.Vertical.bottom)
                }
                .pickerStyle(.segmented)
            } else {
                CombinePositionPicker3x3(
                    label: String(localized: "Before 위치"),
                    selection: $viewModel.settings.beforePosition
                )
                CombinePositionPicker3x3(
                    label: String(localized: "After 위치"),
                    selection: $viewModel.settings.afterPosition
                )
            }
        } header: {
            Text(String(localized: "레이블 모드"))
        }
    }

    private var labelBackgroundSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.labelBackground.isEnabled) {
                Label(String(localized: "배경 사용"), systemImage: "rectangle.fill")
            }
            if viewModel.settings.labelBackground.isEnabled {
                Toggle(isOn: $viewModel.settings.labelBackground.matchBorderColor) {
                    Text(String(localized: "테두리색상과 일치"))
                }
                if !viewModel.settings.labelBackground.matchBorderColor {
                    ColorPicker(
                        String(localized: "색상"),
                        selection: labelBackgroundColorBinding,
                        supportsOpacity: false
                    )
                }
                CombineSliderRow(
                    title: String(localized: "불투명도"),
                    value: $viewModel.settings.labelBackground.opacity,
                    range: CombineSettings.labelBackgroundOpacityRange,
                    step: nil,
                    valueLabel: "\(Int((viewModel.settings.labelBackground.opacity * 100).rounded()))%"
                )
                if viewModel.settings.labelMode == .free {
                    CombineSliderRow(
                        title: String(localized: "곡률"),
                        value: $viewModel.settings.labelBackground.cornerRadius,
                        range: CombineSettings.labelBackgroundCornerRadiusRange,
                        step: 1,
                        valueLabel: "\(Int(viewModel.settings.labelBackground.cornerRadius))pt"
                    )
                }
            }
        } header: {
            Text(String(localized: "레이블 배경"))
        }
    }

    private var previewSection: some View {
        Section {
            CombinePreviewCard(settings: viewModel.settings)
                .frame(maxWidth: .infinity)
        } header: {
            Text(String(localized: "미리보기"))
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
    @State private var viewModel = CombineSettingsViewModel(
        appSettingsRepo: UserDefaultsAppSettingsRepository(
            defaults: UserDefaults(suiteName: "preview-combine") ?? .standard
        )
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
