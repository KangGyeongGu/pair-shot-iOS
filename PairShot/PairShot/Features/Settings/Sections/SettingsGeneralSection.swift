import SwiftUI

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

            Button {
                path.append(.textSizePicker)
            } label: {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(systemImage: "textformat.size", color: .blue),
                    title: String(localized: "settings_item_text_size"),
                    value: viewModel.textSizeDisplayText,
                )
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "settings_section_general"))
        }
    }
}
