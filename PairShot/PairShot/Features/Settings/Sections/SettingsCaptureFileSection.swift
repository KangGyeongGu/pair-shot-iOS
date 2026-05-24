import SwiftUI

struct SettingsCaptureFileSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var path: [Route]

    var body: some View {
        Section {
            Button {
                path.append(.imageQualityPicker)
            } label: {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(systemImage: "photo", color: .blue),
                    title: String(localized: "settings_item_export_quality"),
                    value: viewModel.exportQualityValueText,
                )
            }
            .buttonStyle(.plain)

            overlayOpacityRow

            Button {
                path.append(.filenamePrefixEditor)
            } label: {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(systemImage: "textformat", color: .gray),
                    title: String(localized: "settings_item_file_name_prefix"),
                    value: viewModel.fileNamePrefixDisplay,
                )
            }
            .buttonStyle(.plain)

            embedGPSRow
        } header: {
            Text(String(localized: "settings_section_shooting_files"))
        }
    }

    private var embedGPSRow: some View {
        Toggle(
            isOn: Binding(
                get: { viewModel.embedGPSInPhoto },
                set: { viewModel.embedGPSInPhoto = $0 },
            ),
        ) {
            HStack(spacing: 12) {
                SettingsIconBadge(
                    icon: SettingsRowIcon(systemImage: "location.fill", color: .blue),
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "settings_embed_gps_title"))
                    Text(String(localized: "settings_embed_gps_subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var overlayOpacityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                isOn: Binding(
                    get: { viewModel.overlayAlphaEnabled },
                    set: { viewModel.overlayAlphaEnabled = $0 },
                ),
            ) {
                HStack(spacing: 12) {
                    SettingsIconBadge(
                        icon: SettingsRowIcon(systemImage: "square.on.square", color: .indigo),
                    )
                    Text(String(localized: "settings_item_overlay_opacity"))
                }
            }

            if viewModel.overlayAlphaEnabled {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { viewModel.overlayAlphaValue },
                                set: { viewModel.overlayAlphaValue = $0 },
                            ),
                            in: CompositionDefaults.alphaRange,
                        )
                        Text(viewModel.overlayAlphaPercentText)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                    if viewModel.overlayAlphaValue > 0.75 {
                        InlineWarningLabel(text: String(localized: "settings_warning_opacity_high"))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.overlayAlphaEnabled)
    }
}
