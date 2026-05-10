import SwiftUI

struct SettingsGeneralSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var path: [Route]

    var body: some View {
        Section {
            Button { path.append(.languagePicker) } label: {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(systemImage: "globe", color: .blue),
                    title: String(localized: "settings_item_language"),
                    value: viewModel.languageDisplayText
                )
            }
            .buttonStyle(.plain)

            Button { path.append(.themePicker) } label: {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(systemImage: "circle.lefthalf.filled", color: .indigo),
                    title: String(localized: "settings_item_theme"),
                    value: viewModel.themeDisplayText
                )
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "settings_section_general"))
        }
    }
}

struct SettingsCaptureFileSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var path: [Route]

    var body: some View {
        Section {
            Button { path.append(.imageQualityPicker) } label: {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(systemImage: "photo", color: .blue),
                    title: String(localized: "settings_item_image_quality"),
                    value: viewModel.imageQualityValueText
                )
            }
            .buttonStyle(.plain)

            overlayOpacityRow

            Button { path.append(.filenamePrefixEditor) } label: {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(systemImage: "textformat", color: .gray),
                    title: String(localized: "settings_item_file_name_prefix"),
                    value: viewModel.fileNamePrefixDisplay
                )
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "settings_section_shooting_files"))
        }
    }

    private var overlayOpacityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { viewModel.overlayAlphaEnabled },
                set: { viewModel.overlayAlphaEnabled = $0 }
            )) {
                HStack(spacing: 12) {
                    SettingsIconBadge(
                        icon: SettingsRowIcon(systemImage: "square.on.square", color: .indigo)
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
                                set: { viewModel.overlayAlphaValue = $0 }
                            ),
                            in: CompositionDefaults.alphaRange
                        )
                        Text(viewModel.overlayAlphaPercentText)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                    if viewModel.overlayAlphaValue > 0.75 {
                        Text(String(localized: "settings_warning_opacity_high"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.overlayAlphaEnabled)
    }
}

struct SettingsWatermarkSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var path: [Route]

    var body: some View {
        Section {
            HighlightableCard(isHighlighted: viewModel.shouldPulseWatermark) {
                Toggle(isOn: Binding(
                    get: { viewModel.watermarkEnabled },
                    set: { viewModel.watermarkEnabled = $0 }
                )) {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            icon: SettingsRowIcon(systemImage: "signature", color: .blue)
                        )
                        Text(String(localized: "settings_item_watermark_use"))
                    }
                }
            }
            if viewModel.watermarkEnabled {
                Button {
                    path.append(.watermarkSettings)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            icon: SettingsRowIcon(systemImage: "slider.horizontal.3", color: .blue)
                        )
                        Text(String(localized: "settings_item_user_settings"))
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.watermarkSettingsBlank {
                            Text(String(localized: "settings_warning_required"))
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
            }
        } header: {
            Text(String(localized: "settings_section_watermark"))
        }
    }
}

struct SettingsCombineSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var path: [Route]

    var body: some View {
        Section {
            HighlightableCard(isHighlighted: viewModel.shouldPulseCombine) {
                Button {
                    path.append(.combineSettings)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            icon: SettingsRowIcon(systemImage: "square.on.square", color: .blue)
                        )
                        Text(String(localized: "settings_item_user_settings"))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
            }
        } header: {
            Text(String(localized: "settings_section_combine"))
        }
    }
}

struct SettingsPrivacySection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.embedGPSInPhoto },
                set: { viewModel.embedGPSInPhoto = $0 }
            )) {
                HStack(spacing: 12) {
                    SettingsIconBadge(
                        icon: SettingsRowIcon(systemImage: "location.fill", color: .blue)
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings_embed_gps_title"))
                        Text(String(localized: "settings_embed_gps_subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(String(localized: "settings_embed_gps_section_header"))
        }
    }
}

struct SettingsStorageInfoSection: View {
    @Bindable var viewModel: SettingsViewModel
    let openURL: OpenURLAction

    var body: some View {
        Section {
            SettingsValueRow(
                icon: SettingsRowIcon(systemImage: "photo.stack", color: .blue),
                title: String(localized: "settings_item_photo_storage"),
                value: viewModel.photoStorageText
            )
            SettingsValueRow(
                icon: SettingsRowIcon(systemImage: "internaldrive", color: .gray),
                title: String(localized: "settings_item_cache"),
                value: viewModel.cacheText
            )
            .onTapGesture { viewModel.showCacheClearConfirm = true }
            SettingsValueRow(
                icon: SettingsRowIcon(systemImage: "info.circle", color: .gray),
                title: String(localized: "settings_item_app_version"),
                value: viewModel.appVersionText
            )
            NavigationLink(value: Route.license) {
                HStack(spacing: 12) {
                    SettingsIconBadge(
                        icon: SettingsRowIcon(systemImage: "doc.text", color: .blue)
                    )
                    Text(String(localized: "settings_item_license"))
                }
            }
            HStack(spacing: 12) {
                SettingsIconBadge(
                    icon: SettingsRowIcon(systemImage: "lock.shield", color: .blue)
                )
                Text(String(localized: "settings_item_privacy_policy"))
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { openURL(SettingsExternalLinks.privacyPolicy) }
        } header: {
            Text(String(localized: "settings_section_storage_and_info"))
        }
    }
}

enum SettingsExternalLinks {
    static let privacyPolicy: URL = .init(string: "https://pairshot.kangkyeonggu.com/privacy")!
}
