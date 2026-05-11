import PhotosUI
import SwiftUI

struct WatermarkSettingsView: View {
    @Bindable var viewModel: WatermarkSettingsViewModel
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var bindableAppSettings = appSettings
        VStack(spacing: 0) {
            BannerAdSlot()

            Form {
                basicSection(bindable: $bindableAppSettings.watermarkEnabled)
                if viewModel.settings.type == .text {
                    textSection
                } else {
                    logoSection
                }
            }
            .listStyle(.insetGrouped)
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
                imageData: $viewModel.settings.logoImageData,
                pickerItem: $viewModel.logoPickerItem
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
            WatermarkPreview(settings: viewModel.settings)
        }
        .padding(.top, 8)
        .padding(.horizontal, -16)
    }

    private func basicSection(bindable: Binding<Bool>) -> some View {
        Section {
            Toggle(isOn: bindable) {
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

private struct WatermarkLogoAlphaSlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_logo_alpha"))
                Spacer()
                Text(verbatim: "\(Int((value * 100).rounded()))%")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: WatermarkSettings.logoAlphaRange)
        }
    }
}

private struct WatermarkTextSizeSlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_text_size"))
                Spacer()
                Text(verbatim: String(format: "%.2f", value))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $value,
                in: WatermarkSettings.textSizeRatioRange,
                step: 0.005
            )
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
                in: Double(
                    WatermarkSettings.lineCountRange.lowerBound
                ) ...
                    Double(WatermarkSettings.lineCountRange.upperBound),
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

private struct WatermarkLogoSizeSlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_logo_size"))
                Spacer()
                Text(verbatim: "\(Int((value * 100).rounded()))%")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $value,
                in: WatermarkSettings.logoWidthRatioRange
            )
        }
    }
}

private struct WatermarkLogoPositionPicker: View {
    private static let layout: [[LogoPosition]] = [
        [.topLeft, .topCenter, .topRight],
        [.centerLeft, .center, .centerRight],
        [.bottomLeft, .bottomCenter, .bottomRight],
    ]

    @Binding var selection: LogoPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "watermark_logo_position"))
            VStack(spacing: 6) {
                ForEach(0 ..< Self.layout.count, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(Self.layout[row], id: \.self) { position in
                            cell(for: position)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cell(for position: LogoPosition) -> some View {
        let isActive = selection == position
        Button {
            selection = position
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.85) : Color.appLetterbox.opacity(0.18))
                    .frame(height: 40)
                Image(systemName: isActive ? "checkmark" : "circle.fill")
                    .font(.system(size: isActive ? 16 : 6, weight: .semibold))
                    .foregroundStyle(isActive ? Color.white : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.accessibilityLabel(for: position))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private static func accessibilityLabel(for position: LogoPosition) -> String {
        switch position {
            case .topLeft: String(localized: "watermark_position_top_left")
            case .topCenter: String(localized: "watermark_position_top_center")
            case .topRight: String(localized: "watermark_position_top_right")
            case .centerLeft: String(localized: "watermark_position_center_left")
            case .center: String(localized: "watermark_position_center")
            case .centerRight: String(localized: "watermark_position_center_right")
            case .bottomLeft: String(localized: "watermark_position_bottom_left")
            case .bottomCenter: String(localized: "watermark_position_bottom_center")
            case .bottomRight: String(localized: "watermark_position_bottom_right")
        }
    }
}

private struct WatermarkLogoPickerRow: View {
    @Binding var imageData: Data?
    @Binding var pickerItem: PhotosPickerItem?

    var body: some View {
        let pickerTitle =
            imageData == nil
                ? String(localized: "watermark_logo_pick_action")
                : String(localized: "watermark_logo_replace_action")
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                logoThumbnail
                Spacer()
                PhotosPicker(
                    selection: $pickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(pickerTitle, systemImage: "photo.on.rectangle")
                        .labelStyle(TitleAndIconLabelStyle())
                }
                .buttonStyle(.borderless)
            }
            if imageData != nil {
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        imageData = nil
                        pickerItem = nil
                    } label: {
                        Label(
                            String(localized: "watermark_logo_clear_action"),
                            systemImage: "trash"
                        )
                        .font(.footnote)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder
    private var logoThumbnail: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .background(Color.appLetterbox)
        } else {
            Rectangle()
                .fill(Color.appLetterbox)
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

private struct WatermarkSettingsViewPreviewWrapper: View {
    private static let previewDefaults: UserDefaults = .init(suiteName: "preview-watermark") ?? .standard

    @State private var viewModel = WatermarkSettingsViewModel(
        appSettingsRepo: UserDefaultsAppSettingsRepository(defaults: previewDefaults),
        appSettings: AppSettings(defaults: previewDefaults)
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
