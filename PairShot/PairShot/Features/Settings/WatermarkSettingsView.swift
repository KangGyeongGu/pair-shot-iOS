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
                previewSection
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(String(localized: "watermark_settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.settings) { _, _ in
            Task { await viewModel.saveSettings() }
        }
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

    private var textSection: some View {
        Section {
            WatermarkTextField(text: $viewModel.settings.text)
            WatermarkOpacitySlider(value: $viewModel.settings.opacity)
            WatermarkTextSizeSlider(value: $viewModel.settings.textSizeRatio)
            WatermarkLineCountSlider(value: $viewModel.settings.lineCount)
            WatermarkRepeatSlider(value: $viewModel.settings.repeatCount)
        } header: {
            Text(String(localized: "watermark_section_text"))
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
        }
    }

    private var previewSection: some View {
        Section {
            WatermarkPreview(settings: viewModel.settings)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
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
    @Binding var selection: LogoPosition

    private static let layout: [[LogoPosition]] = [
        [.topLeft, .topCenter, .topRight],
        [.centerLeft, .center, .centerRight],
        [.bottomLeft, .bottomCenter, .bottomRight],
    ]

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
        let pickerTitle = imageData == nil
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
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.appLetterbox)
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

struct WatermarkPreview: View {
    let settings: WatermarkSettings

    var body: some View {
        ZStack {
            sampleBackdrop
            content
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .frame(minHeight: 200)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "watermark_preview_desc"))
    }

    private var sampleBackdrop: some View {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.18, blue: 0.20),
                Color(red: 0.45, green: 0.46, blue: 0.50),
                Color(red: 0.78, green: 0.79, blue: 0.82),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .padding(48)
                .foregroundStyle(.white.opacity(0.18))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch settings.type {
            case .text:
                if settings.text.isEmpty {
                    Text(String(localized: "watermark_preview_empty"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    WatermarkTextPreviewCanvas(settings: settings)
                }

            case .logo:
                WatermarkLogoPreview(settings: settings)
        }
    }
}

private struct WatermarkTextPreviewCanvas: View {
    let settings: WatermarkSettings

    var body: some View {
        Canvas { context, size in
            guard !settings.text.isEmpty,
                  size.width > 0,
                  size.height > 0
            else { return }
            let safeRatio = max(
                WatermarkSettings.textSizeRatioRange.lowerBound,
                min(WatermarkSettings.textSizeRatioRange.upperBound, settings.textSizeRatio)
            )
            let fontSize = max(10, size.width * CGFloat(safeRatio))
            let resolved = context.resolve(
                Text(verbatim: settings.text)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(settings.opacity))
            )
            let textSize = resolved.measure(in: size)
            guard textSize.width > 0, textSize.height > 0 else { return }

            let safeLineCount = max(1, settings.lineCount)
            let safeRepeatCount = max(0.1, settings.repeatCount)
            let diagonal = sqrt(size.width * size.width + size.height * size.height)
            let lineSpacing = diagonal / CGFloat(safeLineCount + 1)
            let textSpacing = max(textSize.width * CGFloat(2.0 / safeRepeatCount), textSize.width + 16)

            context.drawLayer { layer in
                layer.translateBy(x: size.width / 2, y: size.height / 2)
                layer.rotate(by: .degrees(-45))
                layer.translateBy(x: -size.width / 2, y: -size.height / 2)

                let extendedWidth = size.width * 1.5
                let extendedHeight = size.height * 1.5
                let originX = -size.width * 0.25
                let originY = -size.height * 0.25

                var y = originY
                while y < originY + extendedHeight {
                    var x = originX
                    while x < originX + extendedWidth {
                        layer.draw(resolved, at: CGPoint(x: x, y: y), anchor: .topLeading)
                        x += textSpacing
                    }
                    y += lineSpacing
                }
            }
        }
    }
}

private struct WatermarkLogoPreview: View {
    let settings: WatermarkSettings

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                if let data = settings.logoImageData,
                   let uiImage = UIImage(data: data)
                {
                    let ratio = clampedRatio(settings.logoWidthRatio)
                    let width = geometry.size.width * CGFloat(ratio)
                    let aspect = uiImage.size.height / max(uiImage.size.width, 1)
                    let height = width * aspect
                    let padding = geometry.size.width * 0.02
                    let origin = computeOrigin(
                        in: geometry.size,
                        width: width,
                        height: height,
                        padding: padding,
                        position: settings.logoPosition
                    )
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: height)
                        .opacity(settings.logoAlpha)
                        .offset(x: origin.x, y: origin.y)
                } else {
                    Text(String(localized: "watermark_preview_empty"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func clampedRatio(_ value: Double) -> Double {
        max(
            WatermarkSettings.logoWidthRatioRange.lowerBound,
            min(WatermarkSettings.logoWidthRatioRange.upperBound, value)
        )
    }

    // swiftlint:disable function_parameter_count
    private func computeOrigin(
        in canvas: CGSize,
        width: CGFloat,
        height: CGFloat,
        padding: CGFloat,
        position: LogoPosition
    ) -> CGPoint {
        switch position {
            case .topLeft: CGPoint(x: padding, y: padding)
            case .topCenter: CGPoint(x: (canvas.width - width) / 2, y: padding)
            case .topRight: CGPoint(x: canvas.width - width - padding, y: padding)
            case .centerLeft: CGPoint(x: padding, y: (canvas.height - height) / 2)
            case .center: CGPoint(x: (canvas.width - width) / 2, y: (canvas.height - height) / 2)
            case .centerRight: CGPoint(x: canvas.width - width - padding, y: (canvas.height - height) / 2)
            case .bottomLeft: CGPoint(x: padding, y: canvas.height - height - padding)
            case .bottomCenter: CGPoint(x: (canvas.width - width) / 2, y: canvas.height - height - padding)
            case .bottomRight: CGPoint(x: canvas.width - width - padding, y: canvas.height - height - padding)
        }
    }
    // swiftlint:enable function_parameter_count
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
