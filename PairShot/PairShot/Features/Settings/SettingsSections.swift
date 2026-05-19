import SwiftUI
import UIKit

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

struct SettingsWatermarkSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var path: [Route]
    @Environment(RewardedAdManager.self) private var rewardedManager

    var body: some View {
        Section {
            HighlightableCard(isHighlighted: viewModel.shouldPulseWatermark) {
                Toggle(
                    isOn: Binding(
                        get: { viewModel.watermarkEnabled },
                        set: { viewModel.watermarkEnabled = $0 },
                    ),
                ) {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            icon: SettingsRowIcon(systemImage: "signature", color: .blue),
                        )
                        Text(String(localized: "settings_item_watermark_use"))
                    }
                }
            }
            if viewModel.watermarkEnabled {
                Button {
                    if viewModel.requestWatermarkGate(rewardedManager: rewardedManager) {
                        path.append(.watermarkSettings)
                    }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            icon: SettingsRowIcon(systemImage: "slider.horizontal.3", color: .blue),
                        )
                        Text(String(localized: "settings_item_user_settings"))
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.watermarkSettingsBlank {
                            InlineWarningLabel(text: String(localized: "settings_warning_setup_needed"))
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
    @Environment(RewardedAdManager.self) private var rewardedManager

    var body: some View {
        Section {
            HighlightableCard(isHighlighted: viewModel.shouldPulseCombine) {
                Button {
                    if viewModel.requestCombineGate(rewardedManager: rewardedManager) {
                        path.append(.combineSettings)
                    }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            icon: SettingsRowIcon(systemImage: "square.on.square", color: .blue),
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

struct SettingsGeneralSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var path: [Route]

    var body: some View {
        Section {
            Button {
                path.append(.languagePicker)
            } label: {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(systemImage: "globe", color: .blue),
                    title: String(localized: "settings_item_language"),
                    value: viewModel.languageDisplayText,
                )
            }
            .buttonStyle(.plain)

            Button {
                path.append(.themePicker)
            } label: {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(systemImage: "circle.lefthalf.filled", color: .indigo),
                    title: String(localized: "settings_item_theme"),
                    value: viewModel.themeDisplayText,
                )
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "settings_section_general"))
        }
    }
}

struct SettingsHelpSection: View {
    @Binding var path: [Route]
    @Environment(AppEnvironment.self) private var env
    @AppStorage("tutorial.completed") private var tutorialCompleted = false
    @State private var showTutorialRestartDialog = false

    var body: some View {
        Section {
            Button {
                showTutorialRestartDialog = true
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(
                        icon: SettingsRowIcon(systemImage: "questionmark.circle", color: .blue),
                    )
                    Text(String(localized: "settings_item_tutorial_restart"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "settings_section_help"))
        }
        .alert(
            String(localized: "settings_tutorial_restart_confirm_title"),
            isPresented: $showTutorialRestartDialog,
        ) {
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
            Button(String(localized: "common_button_confirm")) {
                restartTutorial()
            }
        } message: {
            Text(String(localized: "settings_tutorial_restart_confirm_message"))
        }
    }

    private func restartTutorial() {
        tutorialCompleted = false
        env.tutorialCoordinator.restart()
        path.removeAll()
    }
}

struct SettingsStorageInfoSection: View {
    @Bindable var viewModel: SettingsViewModel
    let openURL: OpenURLAction
    @Binding var path: [Route]
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Section {
            SettingsValueRow(
                icon: SettingsRowIcon(systemImage: "info.circle", color: .gray),
                title: String(localized: "settings_item_app_version"),
                value: viewModel.appVersionText,
            )
            NavigationLink(value: Route.license) {
                HStack(spacing: 12) {
                    SettingsIconBadge(
                        icon: SettingsRowIcon(systemImage: "doc.text", color: .blue),
                    )
                    Text(String(localized: "settings_item_license"))
                }
            }
            NavigationLink(value: Route.businessInfo) {
                HStack(spacing: 12) {
                    SettingsIconBadge(
                        icon: SettingsRowIcon(systemImage: "building.2", color: .blue),
                    )
                    Text(String(localized: "settings_item_business_info"))
                }
            }
            HStack(spacing: 12) {
                SettingsIconBadge(
                    icon: SettingsRowIcon(systemImage: "lock.shield", color: .blue),
                )
                Text(String(localized: "settings_item_privacy_policy"))
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { openURL(SettingsExternalLinks.privacyPolicy) }

            if env.consentManager.canShowPrivacyOptionsButton {
                Button {
                    Task { await env.consentManager.presentPrivacyOptions() }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            icon: SettingsRowIcon(systemImage: "hand.raised.fill", color: .blue),
                        )
                        Text(String(localized: "settings_privacy_options"))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(String(localized: "settings_section_storage_and_info"))
        }
    }
}

struct SettingsProPromoCard: View {
    let onLearnMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(String(localized: "settings_pro_promo_title"))
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 10) {
                promoFeatureRow(text: String(localized: "settings_pro_promo_feature_pairs"))
                promoFeatureRow(text: String(localized: "settings_pro_promo_feature_no_ads"))
                promoFeatureRow(text: String(localized: "settings_pro_promo_feature_full_access"))
            }

            Button(action: onLearnMore) {
                Text(String(localized: "settings_pro_promo_cta"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground)),
        )
    }

    private func promoFeatureRow(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tint)
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

enum SettingsExternalLinks {
    static var privacyPolicy: URL {
        PaywallURLs.privacy
    }
}
