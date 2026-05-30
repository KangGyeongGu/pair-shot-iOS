import Foundation

extension ExportSettingsViewModel {
    func refreshFromActivePreset() {
        guard exportPresetStore?.active != nil else { return }
        includeCombined = preferences.includeCombined
        includeBefore = preferences.includeBefore
        includeAfter = preferences.includeAfter
        format = preferences.format
        applyCombineSettings = preferences.applyCombineSettings
    }

    func handleSlotTap(at index: Int) {
        guard let store = exportPresetStore else { return }
        if !canAccessSlot(index: index) {
            showPaywall = true
            return
        }
        if store.presets[index] == nil {
            pendingPresetSaveSlotIndex = index
            presetSaveNameInput = ""
            return
        }
        if index == store.activeIndex { return }
        store.switchActive(to: index)
        refreshFromActivePreset()
    }

    func handleSlotLongPress(at index: Int) {
        guard let store = exportPresetStore else { return }
        guard canAccessSlot(index: index) else { return }
        guard store.presets[index] != nil else { return }
        pendingPresetActionSheetSlotIndex = index
    }

    func confirmPresetSave() {
        guard let index = pendingPresetSaveSlotIndex else { return }
        let trimmed = presetSaveNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = String(trimmed.prefix(Self.presetNameMaxLength))
        let name = clipped.isEmpty ? defaultPresetName(forSlot: index) : clipped
        exportPresetStore?.save(at: index, name: name)
        exportPresetStore?.switchActive(to: index)
        refreshFromActivePreset()
        pendingPresetSaveSlotIndex = nil
        presetSaveNameInput = ""
    }

    func cancelPresetSave() {
        pendingPresetSaveSlotIndex = nil
        presetSaveNameInput = ""
    }

    func beginPresetRename(at index: Int) {
        guard let preset = exportPresetStore?.presets[index] else { return }
        pendingPresetRenameSlotIndex = index
        presetRenameNameInput = preset.name
        pendingPresetActionSheetSlotIndex = nil
    }

    func confirmPresetRename() {
        guard let index = pendingPresetRenameSlotIndex else { return }
        let trimmed = presetRenameNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = String(trimmed.prefix(Self.presetNameMaxLength))
        guard !clipped.isEmpty else {
            cancelPresetRename()
            return
        }
        exportPresetStore?.rename(at: index, to: clipped)
        pendingPresetRenameSlotIndex = nil
        presetRenameNameInput = ""
    }

    func cancelPresetRename() {
        pendingPresetRenameSlotIndex = nil
        presetRenameNameInput = ""
    }

    func beginPresetDelete(at index: Int) {
        pendingPresetDeleteSlotIndex = index
        pendingPresetActionSheetSlotIndex = nil
    }

    func confirmPresetDelete() {
        guard let index = pendingPresetDeleteSlotIndex else { return }
        let wasActive = exportPresetStore?.activeIndex == index
        exportPresetStore?.delete(at: index)
        pendingPresetDeleteSlotIndex = nil
        if wasActive { refreshFromActivePreset() }
    }

    func cancelPresetDelete() {
        pendingPresetDeleteSlotIndex = nil
    }

    func canAccessSlot(index: Int) -> Bool {
        if index == 0 { return true }
        return isProUser
    }

    func defaultPresetName(forSlot index: Int) -> String {
        String(format: String(localized: "export_preset_default_name_template"), index + 1)
    }
}
