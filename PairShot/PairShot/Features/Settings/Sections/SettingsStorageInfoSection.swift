import SwiftUI

struct SettingsStorageInfoSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var path: [Route]

    var body: some View {
        Section {
            SettingsValueRow(
                icon: SettingsRowIcon(systemImage: "info.circle", color: .gray),
                title: String(localized: "settings_item_app_version"),
                value: viewModel.appVersionText,
            )
            NavigationLink(value: Route.info) {
                HStack(spacing: 12) {
                    SettingsIconBadge(
                        icon: SettingsRowIcon(systemImage: "doc.badge.gearshape", color: .blue),
                    )
                    Text(String(localized: "settings_item_info"))
                }
            }
        } header: {
            Text(String(localized: "settings_section_info"))
        }
    }
}
