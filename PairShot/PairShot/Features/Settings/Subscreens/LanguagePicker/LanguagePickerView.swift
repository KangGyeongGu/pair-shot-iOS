import SwiftUI

struct LanguagePickerView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    LanguagePickerRow(
                        language: language,
                        isSelected: viewModel.appSettings.language == language
                    ) {
                        viewModel.setLanguage(language)
                        dismiss()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "settings_dialog_language_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LanguagePickerRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(language.displayName)
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
