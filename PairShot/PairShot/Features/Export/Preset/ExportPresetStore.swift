import Foundation
import Observation

@MainActor
@Observable
final class ExportPresetStore {
    static let maxSlots = 4
    static let storeKey = "pairshot.exportPresets"
    static let activeKey = "pairshot.exportPresetsActiveIndex"

    private(set) var presets: [ExportPreset?]
    private(set) var activeIndex: Int

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let appSettings: AppSettings
    @ObservationIgnored private let preferences: ExportPreferences

    var active: ExportPreset? {
        guard presets.indices.contains(activeIndex) else { return nil }
        return presets[activeIndex]
    }

    init(
        appSettings: AppSettings,
        preferences: ExportPreferences,
        defaults: UserDefaults = .standard,
    ) {
        self.defaults = defaults
        self.appSettings = appSettings
        self.preferences = preferences
        presets = Self.loadPresets(defaults: defaults)
        let storedActive = defaults.integer(forKey: Self.activeKey)
        activeIndex = (0 ..< Self.maxSlots).contains(storedActive) ? storedActive : 0
    }

    func seedDefaultIfNeeded(name: String) {
        guard presets[0] == nil else { return }
        let preset = snapshotFromGlobal(name: name)
        presets[0] = preset
        activeIndex = 0
        persist()
    }

    func save(at index: Int, name: String) {
        guard presets.indices.contains(index) else { return }
        let preset = snapshotFromGlobal(name: name)
        presets[index] = preset
        persist()
    }

    func delete(at index: Int) {
        guard index != 0 else { return }
        guard presets.indices.contains(index) else { return }
        let wasActive = activeIndex == index
        let activeShiftsLeft = activeIndex > index
        presets.remove(at: index)
        presets.append(nil)
        if wasActive {
            activeIndex = 0
            if let fallback = presets[0] {
                applyToGlobal(fallback)
            }
        } else if activeShiftsLeft {
            activeIndex -= 1
        }
        persist()
    }

    func rename(at index: Int, to newName: String) {
        guard presets.indices.contains(index) else { return }
        guard var preset = presets[index] else { return }
        preset.name = newName
        presets[index] = preset
        persist()
    }

    func switchActive(to index: Int) {
        guard presets.indices.contains(index) else { return }
        guard let preset = presets[index] else { return }
        activeIndex = index
        applyToGlobal(preset)
        persist()
    }

    func syncFromGlobal() {
        guard var preset = active else { return }
        preset.includeCombined = preferences.includeCombined
        preset.includeBefore = preferences.includeBefore
        preset.includeAfter = preferences.includeAfter
        preset.format = preferences.format
        preset.applyCombineSettings = preferences.applyCombineSettings
        preset.combineSettings = appSettings.combineSettings
        preset.applyWatermark = appSettings.watermarkEnabled
        preset.watermarkSettings = appSettings.watermarkSettings
        presets[activeIndex] = preset
        persist()
    }

    private func snapshotFromGlobal(name: String) -> ExportPreset {
        ExportPreset(
            name: name,
            includeCombined: preferences.includeCombined,
            includeBefore: preferences.includeBefore,
            includeAfter: preferences.includeAfter,
            format: preferences.format,
            applyCombineSettings: preferences.applyCombineSettings,
            combineSettings: appSettings.combineSettings,
            applyWatermark: appSettings.watermarkEnabled,
            watermarkSettings: appSettings.watermarkSettings,
        )
    }

    private func applyToGlobal(_ preset: ExportPreset) {
        preferences.includeCombined = preset.includeCombined
        preferences.includeBefore = preset.includeBefore
        preferences.includeAfter = preset.includeAfter
        preferences.format = preset.format
        preferences.applyCombineSettings = preset.applyCombineSettings
        appSettings.combineSettings = preset.combineSettings
        appSettings.watermarkEnabled = preset.applyWatermark
        appSettings.watermarkSettings = preset.watermarkSettings
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: Self.storeKey)
        }
        defaults.set(activeIndex, forKey: Self.activeKey)
    }

    private static func loadPresets(defaults: UserDefaults) -> [ExportPreset?] {
        guard let data = defaults.data(forKey: storeKey),
              let decoded = try? JSONDecoder().decode([ExportPreset?].self, from: data),
              decoded.count == Self.maxSlots
        else {
            return [ExportPreset?](repeating: nil, count: maxSlots)
        }
        return decoded
    }
}
