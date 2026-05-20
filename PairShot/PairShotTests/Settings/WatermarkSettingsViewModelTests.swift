import Foundation
@testable import PairShot
import Testing

@MainActor
struct WatermarkSettingsViewModelTests {
    @Test
    func `init — snapshot 의 watermark 가 있으면 그 값으로 초기화`() {
        let custom = WatermarkSettings(type: .text, text: "Existing", opacity: 0.8)
        let snapshot = Self.makeSnapshot(watermark: custom)
        let repo = InMemoryAppSettingsRepo(snapshot: snapshot)
        let appSettings = Self.makeAppSettings()

        let viewModel = WatermarkSettingsViewModel(appSettingsRepo: repo, appSettings: appSettings)

        #expect(viewModel.settings.text == "Existing")
        #expect(viewModel.settings.opacity == 0.8)
    }

    @Test
    func `init — snapshot 의 watermark 가 nil 이면 default 로 fallback`() {
        let snapshot = Self.makeSnapshot(watermark: nil)
        let repo = InMemoryAppSettingsRepo(snapshot: snapshot)
        let appSettings = Self.makeAppSettings()

        let viewModel = WatermarkSettingsViewModel(appSettingsRepo: repo, appSettings: appSettings)

        #expect(viewModel.settings == WatermarkSettings.default)
    }

    @Test
    func `saveSettings — appSettings 와 repo snapshot 양쪽에 즉시 반영`() async {
        let snapshot = Self.makeSnapshot(watermark: nil)
        let repo = InMemoryAppSettingsRepo(snapshot: snapshot)
        let appSettings = Self.makeAppSettings()
        let viewModel = WatermarkSettingsViewModel(appSettingsRepo: repo, appSettings: appSettings)
        viewModel.settings.text = "Updated"
        viewModel.settings.opacity = 0.42

        await viewModel.saveSettings()

        #expect(appSettings.watermarkSettings.text == "Updated")
        #expect(appSettings.watermarkSettings.opacity == 0.42)
        #expect(repo.saveCount == 1)
        #expect(repo.lastSavedSnapshot?.watermark?.text == "Updated")
        #expect(repo.lastSavedSnapshot?.watermark?.opacity == 0.42)
    }

    @Test
    func `saveSettings — 여러 번 호출 시 매번 repo 에 persist (최신 값 반영)`() async {
        let snapshot = Self.makeSnapshot(watermark: nil)
        let repo = InMemoryAppSettingsRepo(snapshot: snapshot)
        let appSettings = Self.makeAppSettings()
        let viewModel = WatermarkSettingsViewModel(appSettingsRepo: repo, appSettings: appSettings)

        viewModel.settings.text = "First"
        await viewModel.saveSettings()
        viewModel.settings.text = "Second"
        viewModel.settings.type = .logo
        await viewModel.saveSettings()

        #expect(repo.saveCount == 2)
        #expect(repo.lastSavedSnapshot?.watermark?.text == "Second")
        #expect(repo.lastSavedSnapshot?.watermark?.type == .logo)
        #expect(appSettings.watermarkSettings.text == "Second")
        #expect(appSettings.watermarkSettings.type == .logo)
    }

    private static func makeAppSettings() -> AppSettings {
        let suiteName = "watermark-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    private static func makeSnapshot(watermark: WatermarkSettings?) -> AppSettingsSnapshot {
        AppSettingsSnapshot(
            exportQualityRawValue: AppSettingsSnapshot.defaultExportQualityRawValue,
            fileNamePrefix: "",
            defaultOverlayAlpha: 0.5,
            defaultCompositeLayoutRawValue: AppSettingsSnapshot.defaultCompositeLayoutFallback,
            watermarkEnabled: false,
            language: .system,
            theme: .system,
            watermark: watermark,
            combine: nil,
        )
    }
}

private final class InMemoryAppSettingsRepo: AppSettingsRepository, @unchecked Sendable {
    private(set) var snapshot: AppSettingsSnapshot
    private(set) var lastSavedSnapshot: AppSettingsSnapshot?
    private(set) var saveCount = 0

    init(snapshot: AppSettingsSnapshot) {
        self.snapshot = snapshot
    }

    func load() -> AppSettingsSnapshot {
        snapshot
    }

    func save(_ settings: AppSettingsSnapshot) async throws {
        snapshot = settings
        lastSavedSnapshot = settings
        saveCount += 1
    }
}
