import SwiftUI

struct ThemePickerView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    ThemePickerRow(
                        theme: theme,
                        isSelected: viewModel.appSettings.theme == theme,
                    ) {
                        viewModel.setTheme(theme)
                        dismiss()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "settings_dialog_theme_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThemePickerRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(theme.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
