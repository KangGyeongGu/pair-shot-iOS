import Observation

@MainActor
@Observable
final class CombineSettingsViewModel {
    var settings: CombineSettings

    private let appSettingsRepo: AppSettingsRepository
    private let appSettings: AppSettings
    private let exportPresetStore: ExportPresetStore?

    init(
        appSettingsRepo: AppSettingsRepository,
        appSettings: AppSettings,
        exportPresetStore: ExportPresetStore? = nil,
    ) {
        self.appSettingsRepo = appSettingsRepo
        self.appSettings = appSettings
        self.exportPresetStore = exportPresetStore
        let snapshot = appSettingsRepo.load()
        settings = snapshot.combine ?? .default
    }

    func saveSettings() async {
        appSettings.combineSettings = settings
        var snapshot = appSettingsRepo.load()
        snapshot.combine = settings
        try? await appSettingsRepo.save(snapshot)
        exportPresetStore?.syncFromGlobal()
    }
}
