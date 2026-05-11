import SwiftUI

struct CompositionSettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        Form {
            overlayAlphaSection
            layoutSection
            watermarkSection
        }
        .navigationTitle(String(localized: "composition_settings_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overlayAlphaSection: some View {
        Section {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.tint)
                    Slider(
                        value: alphaBinding,
                        in: CompositionDefaults.alphaRange
                    )
                    Text(percentLabel(appSettings.defaultOverlayAlpha))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
            }
        } header: {
            Text(String(localized: "composition_section_overlay"))
        } footer: {
            Text(String(localized: "composition_overlay_hint_after_camera"))
        }
    }

    private var alphaBinding: Binding<Double> {
        Binding(
            get: { CompositionDefaults.clampAlpha(appSettings.defaultOverlayAlpha) },
            set: { appSettings.defaultOverlayAlpha = CompositionDefaults.clampAlpha($0) }
        )
    }

    private var layoutSection: some View {
        Section {
            Picker(String(localized: "composition_section_layout"), selection: layoutBinding) {
                ForEach(CompositeLayout.allCases) { layout in
                    Label(layout.label, systemImage: layout.systemImage)
                        .tag(layout)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(String(localized: "composition_section_layout"))
        } footer: {
            Text(layoutFooter)
        }
    }

    private var layoutBinding: Binding<CompositeLayout> {
        Binding(
            get: { appSettings.defaultCompositeLayout },
            set: { appSettings.defaultCompositeLayout = $0 }
        )
    }

    private var layoutFooter: String {
        switch appSettings.defaultCompositeLayout {
            case .horizontal:
                String(localized: "composition_layout_left_right_desc")

            case .vertical:
                String(localized: "composition_layout_top_bottom_desc")
        }
    }

    private var watermarkSection: some View {
        Section {
            Toggle(isOn: watermarkBinding) {
                Label(
                    String(localized: "composition_overlay_show_watermark"),
                    systemImage: "signature"
                )
            }
        } header: {
            Text(String(localized: "composition_section_watermark"))
        } footer: {
            Text(String(localized: "composition_watermark_hint"))
        }
    }

    private var watermarkBinding: Binding<Bool> {
        Binding(
            get: { appSettings.watermarkEnabled },
            set: { appSettings.watermarkEnabled = $0 }
        )
    }

    private func percentLabel(_ value: Double) -> String {
        let pct = Int((CompositionDefaults.clampAlpha(value) * 100).rounded())
        return "\(pct)%"
    }
}

private struct CompositionSettingsViewPreviewWrapper: View {
    var body: some View {
        NavigationStack {
            CompositionSettingsView()
        }
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview-composition") ?? .standard))
    }
}

#Preview {
    CompositionSettingsViewPreviewWrapper()
}
