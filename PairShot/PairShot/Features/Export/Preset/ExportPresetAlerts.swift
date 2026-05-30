import SwiftUI

struct ExportPresetAlerts: ViewModifier {
    @Bindable var viewModel: ExportSettingsViewModel

    private var saveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPresetSaveSlotIndex != nil },
            set: { if !$0 { viewModel.cancelPresetSave() } },
        )
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPresetRenameSlotIndex != nil },
            set: { if !$0 { viewModel.cancelPresetRename() } },
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPresetDeleteSlotIndex != nil },
            set: { if !$0 { viewModel.cancelPresetDelete() } },
        )
    }

    private var actionSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingPresetActionSheetSlotIndex != nil },
            set: { if !$0 { viewModel.pendingPresetActionSheetSlotIndex = nil } },
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "export_preset_save_title"),
                isPresented: saveBinding,
            ) {
                TextField(
                    String(localized: "export_preset_name_placeholder"),
                    text: $viewModel.presetSaveNameInput,
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.cancelPresetSave()
                }
                Button(String(localized: "common_button_confirm")) {
                    viewModel.confirmPresetSave()
                }
            } message: {
                Text(String(localized: "export_preset_save_message"))
            }
            .alert(
                String(localized: "export_preset_rename_title"),
                isPresented: renameBinding,
            ) {
                TextField(
                    String(localized: "export_preset_name_placeholder"),
                    text: $viewModel.presetRenameNameInput,
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.cancelPresetRename()
                }
                Button(String(localized: "common_button_confirm")) {
                    viewModel.confirmPresetRename()
                }
            }
            .confirmationDialog(
                String(localized: "export_preset_actions_title"),
                isPresented: actionSheetBinding,
                titleVisibility: .visible,
            ) {
                if let index = viewModel.pendingPresetActionSheetSlotIndex {
                    Button(String(localized: "export_preset_action_rename")) {
                        viewModel.beginPresetRename(at: index)
                    }
                    if index != 0 {
                        Button(String(localized: "common_button_delete"), role: .destructive) {
                            viewModel.beginPresetDelete(at: index)
                        }
                    }
                    Button(String(localized: "common_button_cancel"), role: .cancel) {
                        viewModel.pendingPresetActionSheetSlotIndex = nil
                    }
                }
            }
            .alert(
                String(localized: "export_preset_delete_confirm_title"),
                isPresented: deleteBinding,
            ) {
                Button(String(localized: "common_button_cancel"), role: .cancel) {
                    viewModel.cancelPresetDelete()
                }
                Button(String(localized: "common_button_delete"), role: .destructive) {
                    viewModel.confirmPresetDelete()
                }
            } message: {
                Text(String(localized: "export_preset_delete_confirm_message"))
            }
    }
}
