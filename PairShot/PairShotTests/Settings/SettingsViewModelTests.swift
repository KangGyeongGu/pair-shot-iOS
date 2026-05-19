import Foundation
@testable import PairShot
import Testing

@MainActor
struct SettingsViewModelTests {
    @Test
    func `init — overlayAlphaValue, overlayAlphaEnabled 가 appSettings 기존 값으로 초기화`() {
        let env = Self.makeAppSettings()
        env.defaultOverlayAlpha = 0.45
        env.overlayEnabled = true

        let viewModel = SettingsViewModel(appSettings: env)

        #expect(viewModel.overlayAlphaValue == 0.45)
        #expect(viewModel.overlayAlphaEnabled)
    }

    @Test
    func `overlayAlphaEnabled didSet — appSettings 에 즉시 반영`() {
        let env = Self.makeAppSettings()
        let viewModel = SettingsViewModel(appSettings: env)

        viewModel.overlayAlphaEnabled = true
        #expect(env.overlayEnabled)

        viewModel.overlayAlphaEnabled = false
        #expect(!env.overlayEnabled)
    }

    @Test
    func `overlayAlphaValue didSet — clamp 후 appSettings 에 persist`() {
        let env = Self.makeAppSettings()
        let viewModel = SettingsViewModel(appSettings: env)

        viewModel.overlayAlphaValue = 1.5
        #expect(env.defaultOverlayAlpha == CompositionDefaults.clampAlpha(1.5))

        viewModel.overlayAlphaValue = -0.3
        #expect(env.defaultOverlayAlpha == CompositionDefaults.clampAlpha(-0.3))
    }

    @Test
    func `overlayAlphaPercentText — 0_0 → 0%, 0_5 → 50%, 1_0 → 100% (반올림)`() {
        let env = Self.makeAppSettings()
        let viewModel = SettingsViewModel(appSettings: env)

        viewModel.overlayAlphaValue = 0.0
        #expect(viewModel.overlayAlphaPercentText == "0%")

        viewModel.overlayAlphaValue = 0.5
        #expect(viewModel.overlayAlphaPercentText == "50%")

        viewModel.overlayAlphaValue = 1.0
        #expect(viewModel.overlayAlphaPercentText == "100%")

        viewModel.overlayAlphaValue = 0.756
        #expect(viewModel.overlayAlphaPercentText == "76%")
    }

    @Test
    func `setLanguage — 이전과 다른 언어로 변경 시 showLanguageRestartAlert true`() {
        let env = Self.makeAppSettings()
        env.language = .system
        let viewModel = SettingsViewModel(appSettings: env)

        viewModel.setLanguage(.english)

        #expect(env.language == .english)
        #expect(viewModel.showLanguageRestartAlert)
    }

    @Test
    func `setLanguage — 같은 언어로 set 시 showLanguageRestartAlert false 유지`() {
        let env = Self.makeAppSettings()
        env.language = .english
        let viewModel = SettingsViewModel(appSettings: env)

        viewModel.setLanguage(.english)

        #expect(!viewModel.showLanguageRestartAlert)
    }

    @Test
    func `setTheme — appSettings_theme 에 반영`() {
        let env = Self.makeAppSettings()
        let viewModel = SettingsViewModel(appSettings: env)

        viewModel.setTheme(.dark)

        #expect(env.theme == .dark)
    }

    @Test
    func `setExportQuality — appSettings_exportQuality 에 반영`() {
        let env = Self.makeAppSettings()
        let viewModel = SettingsViewModel(appSettings: env)

        viewModel.setExportQuality(.standard)

        #expect(env.exportQuality == .standard)
    }

    @Test
    func `watermarkEnabled getter_setter — appSettings 위임`() {
        let env = Self.makeAppSettings()
        env.watermarkEnabled = false
        let viewModel = SettingsViewModel(appSettings: env)
        #expect(!viewModel.watermarkEnabled)

        viewModel.watermarkEnabled = true
        #expect(env.watermarkEnabled)
    }

    @Test
    func `embedGPSInPhoto getter_setter — appSettings 위임`() {
        let env = Self.makeAppSettings()
        env.embedGPSInPhoto = false
        let viewModel = SettingsViewModel(appSettings: env)
        #expect(!viewModel.embedGPSInPhoto)

        viewModel.embedGPSInPhoto = true
        #expect(env.embedGPSInPhoto)
    }

    @Test
    func `fileNamePrefixDisplay — sanitize 결과 빈 문자열 시 none localized 반환 (forbidden chars only)`() {
        let env = Self.makeAppSettings()
        env.fileNamePrefix = "////"
        let viewModel = SettingsViewModel(appSettings: env)

        #expect(viewModel.fileNamePrefixDisplay == String(localized: "settings_file_name_prefix_none"))
    }

    @Test
    func `fileNamePrefixDisplay — prefix 가 있으면 sanitize 결과 그대로`() {
        let env = Self.makeAppSettings()
        env.fileNamePrefix = "PHOTO"
        let viewModel = SettingsViewModel(appSettings: env)

        #expect(viewModel.fileNamePrefixDisplay == "PHOTO")
    }

    @Test
    func `triggerPulse — flag 즉시 true 로 설정 (동기적)`() {
        let env = Self.makeAppSettings()
        let viewModel = SettingsViewModel(appSettings: env)
        #expect(!viewModel.shouldPulseWatermark)

        viewModel.triggerPulse(\.shouldPulseWatermark)
        #expect(viewModel.shouldPulseWatermark)
    }

    @Test
    func `triggerPulse — delay 경과 후 flag 자동 false 복귀 (task value await)`() async {
        let env = Self.makeAppSettings()
        let viewModel = SettingsViewModel(appSettings: env)

        let task = viewModel.triggerPulse(\.shouldPulseCombine, delay: .zero)
        await task.value

        #expect(!viewModel.shouldPulseCombine)
    }

    private static func makeAppSettings() -> AppSettings {
        let suiteName = "settings-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }
}

@MainActor
struct CombineSettingsViewModelTests {
    @Test
    func `init — snapshot 의 combine 이 있으면 그 값으로 초기화`() {
        let custom = CombineSettings(direction: .vertical)
        let snapshot = Self.makeSnapshot(combine: custom)
        let repo = InMemoryAppSettingsRepo(snapshot: snapshot)
        let appSettings = Self.makeAppSettings()

        let viewModel = CombineSettingsViewModel(appSettingsRepo: repo, appSettings: appSettings)

        #expect(viewModel.settings.direction == .vertical)
    }

    @Test
    func `init — snapshot 의 combine 이 nil 이면 default 로 fallback`() {
        let snapshot = Self.makeSnapshot(combine: nil)
        let repo = InMemoryAppSettingsRepo(snapshot: snapshot)
        let appSettings = Self.makeAppSettings()

        let viewModel = CombineSettingsViewModel(appSettingsRepo: repo, appSettings: appSettings)

        #expect(viewModel.settings == CombineSettings.default)
    }

    @Test
    func `saveSettings — appSettings 와 repo snapshot 양쪽에 persist`() async {
        let snapshot = Self.makeSnapshot(combine: nil)
        let repo = InMemoryAppSettingsRepo(snapshot: snapshot)
        let appSettings = Self.makeAppSettings()
        let viewModel = CombineSettingsViewModel(appSettingsRepo: repo, appSettings: appSettings)
        viewModel.settings.direction = .vertical

        await viewModel.saveSettings()

        #expect(appSettings.combineSettings.direction == .vertical)
        #expect(repo.saveCount == 1)
        #expect(repo.lastSavedSnapshot?.combine?.direction == .vertical)
    }

    @Test
    func `saveSettings — 여러 번 호출 시 매번 repo 에 persist`() async {
        let snapshot = Self.makeSnapshot(combine: nil)
        let repo = InMemoryAppSettingsRepo(snapshot: snapshot)
        let appSettings = Self.makeAppSettings()
        let viewModel = CombineSettingsViewModel(appSettingsRepo: repo, appSettings: appSettings)

        viewModel.settings.border.isEnabled = false
        await viewModel.saveSettings()
        viewModel.settings.border.thickness = 20
        await viewModel.saveSettings()

        #expect(repo.saveCount == 2)
        #expect(repo.lastSavedSnapshot?.combine?.border.thickness == 20)
        #expect(repo.lastSavedSnapshot?.combine?.border.isEnabled == false)
    }

    private static func makeAppSettings() -> AppSettings {
        let suiteName = "combine-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    private static func makeSnapshot(combine: CombineSettings?) -> AppSettingsSnapshot {
        AppSettingsSnapshot(
            exportQualityRawValue: AppSettingsSnapshot.defaultExportQualityRawValue,
            fileNamePrefix: "",
            defaultOverlayAlpha: 0.5,
            defaultCompositeLayoutRawValue: AppSettingsSnapshot.defaultCompositeLayoutFallback,
            watermarkEnabled: false,
            language: .system,
            theme: .system,
            watermark: nil,
            combine: combine,
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
