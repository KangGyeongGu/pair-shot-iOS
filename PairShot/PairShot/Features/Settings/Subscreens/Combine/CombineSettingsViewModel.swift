import Observation

@MainActor
@Observable
final class CombineSettingsViewModel {
    var settings: CombineSettings

    private let appSettingsRepo: AppSettingsRepository
    private let appSettings: AppSettings

    init(appSettingsRepo: AppSettingsRepository, appSettings: AppSettings) {
        self.appSettingsRepo = appSettingsRepo
        self.appSettings = appSettings
        let snapshot = appSettingsRepo.load()
        settings = snapshot.combine ?? .default
    }

    func saveSettings() async {
        appSettings.combineSettings = settings
        var snapshot = appSettingsRepo.load()
        snapshot.combine = settings
        try? await appSettingsRepo.save(snapshot)
    }
}
