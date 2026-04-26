import Foundation
import Observation

@MainActor
@Observable
final class WatermarkSettingsViewModel {
    var settings: WatermarkSettings

    private let appSettingsRepo: AppSettingsRepository

    init(appSettingsRepo: AppSettingsRepository) {
        self.appSettingsRepo = appSettingsRepo
        let snapshot = appSettingsRepo.load()
        settings = snapshot.watermark ?? .default
    }

    func saveSettings() async {
        var snapshot = appSettingsRepo.load()
        snapshot.watermark = settings
        try? await appSettingsRepo.save(snapshot)
    }

    deinit {}
}
