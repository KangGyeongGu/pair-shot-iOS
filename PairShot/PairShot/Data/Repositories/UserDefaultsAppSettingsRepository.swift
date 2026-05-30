import Foundation

final nonisolated class UserDefaultsAppSettingsRepository: AppSettingsRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let logoStore: WatermarkLogoStore

    init(
        defaults: UserDefaults = .standard,
        logoStore: WatermarkLogoStore = WatermarkLogoStore(),
    ) {
        self.defaults = defaults
        self.logoStore = logoStore
        defaults.register(defaults: AppSettingsDefaultsRegistration.registry)
    }

    func load() -> AppSettingsSnapshot {
        AppSettingsSnapshot(
            exportQualityRawValue: defaults.string(forKey: AppSettingsKeys.exportQuality)
                ?? AppSettingsSnapshot.defaultExportQualityRawValue,
            fileNamePrefix: defaults.string(forKey: AppSettingsKeys.fileNamePrefix) ?? "",
            defaultOverlayAlpha: defaults.double(forKey: AppSettingsKeys.defaultOverlayAlpha),
            defaultCompositeLayoutRawValue: defaults.string(forKey: AppSettingsKeys.defaultCompositeLayout)
                ?? AppSettingsSnapshot.defaultCompositeLayoutFallback,
            watermarkEnabled: defaults.bool(forKey: AppSettingsKeys.watermarkEnabled),
            language: decodeLanguage(),
            theme: decodeTheme(),
            watermark: decodeWatermark(),
            combine: decodeCombine(),
        )
    }

    func save(_ settings: AppSettingsSnapshot) async throws {
        defaults.set(settings.exportQualityRawValue, forKey: AppSettingsKeys.exportQuality)
        defaults.set(settings.fileNamePrefix, forKey: AppSettingsKeys.fileNamePrefix)
        defaults.set(settings.defaultOverlayAlpha, forKey: AppSettingsKeys.defaultOverlayAlpha)
        defaults.set(settings.defaultCompositeLayoutRawValue, forKey: AppSettingsKeys.defaultCompositeLayout)
        defaults.set(settings.watermarkEnabled, forKey: AppSettingsKeys.watermarkEnabled)
        defaults.set(settings.language.rawValue, forKey: AppSettingsKeys.language)
        defaults.set(settings.theme.rawValue, forKey: AppSettingsKeys.theme)
        encodeWatermark(settings.watermark)
        encodeCombine(settings.combine)
    }

    private func decodeLanguage() -> AppLanguage {
        let raw = defaults.string(forKey: AppSettingsKeys.language) ?? AppSettingsSnapshot.defaultLanguage.rawValue
        return AppLanguage(rawValue: raw) ?? AppSettingsSnapshot.defaultLanguage
    }

    private func decodeTheme() -> AppTheme {
        let raw = defaults.string(forKey: AppSettingsKeys.theme) ?? AppSettingsSnapshot.defaultTheme.rawValue
        return AppTheme(rawValue: raw) ?? AppSettingsSnapshot.defaultTheme
    }

    private func decodeWatermark() -> WatermarkSettings? {
        guard let raw = defaults.string(forKey: AppSettingsKeys.watermarkSettings),
              let data = raw.data(using: .utf8)
        else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.userInfo[.watermarkLogoStore] = logoStore
        guard let decoded = try? decoder.decode(WatermarkSettings.self, from: data) else { return nil }
        if let migrated = try? JSONEncoder().encode(decoded),
           let migratedRaw = String(data: migrated, encoding: .utf8),
           migratedRaw != raw
        {
            defaults.set(migratedRaw, forKey: AppSettingsKeys.watermarkSettings)
        }
        return decoded
    }

    private func encodeWatermark(_ watermark: WatermarkSettings?) {
        guard let watermark else {
            defaults.removeObject(forKey: AppSettingsKeys.watermarkSettings)
            return
        }
        guard let data = try? JSONEncoder().encode(watermark),
              let raw = String(data: data, encoding: .utf8)
        else {
            return
        }
        defaults.set(raw, forKey: AppSettingsKeys.watermarkSettings)
    }

    private func decodeCombine() -> CombineSettings? {
        guard let raw = defaults.string(forKey: AppSettingsKeys.combineSettings),
              let data = raw.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(CombineSettings.self, from: data)
    }

    private func encodeCombine(_ combine: CombineSettings?) {
        guard let combine else {
            defaults.removeObject(forKey: AppSettingsKeys.combineSettings)
            return
        }
        guard let data = try? JSONEncoder().encode(combine),
              let raw = String(data: data, encoding: .utf8)
        else {
            return
        }
        defaults.set(raw, forKey: AppSettingsKeys.combineSettings)
    }
}
