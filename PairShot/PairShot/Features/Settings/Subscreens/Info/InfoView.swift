import SwiftUI

struct InfoView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(spacing: 0) {
            BannerAdSlot()

            Form {
                Section {
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
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(String(localized: "settings_info_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
