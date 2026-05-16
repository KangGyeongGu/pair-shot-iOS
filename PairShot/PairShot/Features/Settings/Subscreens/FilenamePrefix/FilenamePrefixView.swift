import SwiftUI

struct FilenamePrefixView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField(
                    String(localized: "settings_dialog_prefix_hint"),
                    text: $draft,
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.done)
                .focused($fieldFocused)
                .onSubmit { commitAndDismiss() }
            } footer: {
                Text(String(localized: "settings_dialog_file_name_prefix_message"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "settings_dialog_file_name_prefix_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common_button_save")) { commitAndDismiss() }
            }
        }
        .onAppear {
            draft = viewModel.appSettings.fileNamePrefix
            fieldFocused = true
        }
    }

    private func commitAndDismiss() {
        let cleaned = FileNamePrefixValidator.sanitize(draft)
        viewModel.appSettings.fileNamePrefix = cleaned
        dismiss()
    }
}
