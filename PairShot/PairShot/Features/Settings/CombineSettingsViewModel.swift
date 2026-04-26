import Foundation
import Observation

@MainActor
@Observable
final class CombineSettingsViewModel {
    var settings: CombineSettings

    private let appSettingsRepo: AppSettingsRepository

    init(appSettingsRepo: AppSettingsRepository) {
        self.appSettingsRepo = appSettingsRepo
        let snapshot = appSettingsRepo.load()
        settings = snapshot.combine ?? .default
    }

    func saveSettings() async {
        var snapshot = appSettingsRepo.load()
        snapshot.combine = settings
        try? await appSettingsRepo.save(snapshot)
    }

    deinit {}
}
