import SwiftUI

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

            HStack(spacing: 12) {
                SettingsIconBadge(
                    icon: SettingsRowIcon(systemImage: "doc.plaintext", color: .blue),
                )
                Text(String(localized: "settings_item_terms_of_use"))
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { openURL(SettingsExternalLinks.termsOfUse) }

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
