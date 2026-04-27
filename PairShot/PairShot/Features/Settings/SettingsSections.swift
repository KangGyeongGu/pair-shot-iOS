import SwiftUI

struct SettingsGeneralSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            SettingsValueRow(
                title: String(localized: "settings_item_language"),
                value: viewModel.languageDisplayText
            )
            .onTapGesture { viewModel.showLanguagePicker = true }

            SettingsValueRow(
                title: String(localized: "settings_item_theme"),
                value: viewModel.themeDisplayText
            )
            .onTapGesture { viewModel.showThemePicker = true }
        } header: {
            Text(String(localized: "settings_section_general"))
        }
    }
}

struct SettingsCaptureFileSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            NavigationLink {
                CaptureSettingsView()
            } label: {
                SettingsRow(
                    title: String(localized: "settings_section_shooting_files"),
                    subtitle: viewModel.captureSummary,
                    systemImage: "camera"
                )
            }
            NavigationLink {
                CompositionSettingsView()
            } label: {
                SettingsRow(
                    title: String(localized: "settings_item_overlay"),
                    subtitle: viewModel.compositionSummary,
                    systemImage: "circle.lefthalf.filled"
                )
            }
        } header: {
            Text(String(localized: "settings_section_shooting_files"))
        } footer: {
            Text(String(localized: "settings_section_shooting_files_hint"))
        }
    }
}

struct SettingsWatermarkSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            HighlightableCard(isHighlighted: viewModel.shouldPulseWatermark) {
                Toggle(isOn: Binding(
                    get: { viewModel.watermarkEnabled },
                    set: { viewModel.watermarkEnabled = $0 }
                )) {
                    Label(
                        String(localized: "settings_item_watermark_use"),
                        systemImage: "signature"
                    )
                }
            }
            if viewModel.watermarkEnabled {
                NavigationLink(value: Route.watermarkSettings) {
                    HStack {
                        Text(String(localized: "settings_item_button_detail"))
                        Spacer()
                        if viewModel.watermarkSettingsBlank {
                            Text(String(localized: "settings_warning_required"))
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        } header: {
            Text(String(localized: "settings_section_watermark"))
        }
    }
}

struct SettingsCombineSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            HighlightableCard(isHighlighted: viewModel.shouldPulseCombine) {
                NavigationLink(value: Route.combineSettings) {
                    Label(
                        String(localized: "settings_item_button_detail"),
                        systemImage: "square.on.square"
                    )
                }
            }
        } header: {
            Text(String(localized: "settings_section_combine"))
        }
    }
}

struct SettingsCouponSection: View {
    let adFreeStore: AdFreeStore

    var body: some View {
        Section {
            NavigationLink {
                AdFreeStatusView()
            } label: {
                SettingsRow(
                    title: String(localized: "settings_item_coupon"),
                    subtitle: couponSummary,
                    systemImage: "ticket"
                )
            }
        } header: {
            Text(String(localized: "settings_section_coupon"))
        }
    }

    private var couponSummary: String {
        adFreeStore.isAdFree
            ? String(localized: "coupon_status_active_short")
            : String(localized: "coupon_status_inactive_short")
    }
}

struct SettingsStorageInfoSection: View {
    @Bindable var viewModel: SettingsViewModel
    let openURL: OpenURLAction

    var body: some View {
        Section {
            SettingsValueRow(
                title: String(localized: "settings_item_storage"),
                value: viewModel.photoStorageText
            )
            SettingsValueRow(
                title: String(localized: "settings_item_cache"),
                value: viewModel.cacheText
            )
            .onTapGesture { viewModel.showCacheClearConfirm = true }
            SettingsValueRow(
                title: String(localized: "settings_item_app_version"),
                value: viewModel.appVersionText
            )
            NavigationLink(value: Route.license) {
                Text(String(localized: "settings_item_license"))
            }
            HStack {
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
    static let privacyPolicy: URL = .init(string: "https://kanggyeonggu.github.io/pairshot/privacy.html")
        ?? URL(string: "https://example.com/privacy")!
}
