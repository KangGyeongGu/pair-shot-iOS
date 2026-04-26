import Foundation

final class UserDefaultsAppSettingsRepository: AppSettingsRepository, @unchecked Sendable {
    static let jpegQualityKey = "pairshot.jpegQuality"
    static let fileNamePrefixKey = "pairshot.fileNamePrefix"
    static let defaultOverlayAlphaKey = "pairshot.defaultOverlayAlpha"
    static let defaultCompositeLayoutKey = "pairshot.defaultCompositeLayout"
    static let watermarkEnabledKey = "watermarkEnabled"
    static let watermarkSettingsKey = "pairshot.watermarkSettings"
    static let combineSettingsKey = "pairshot.combineSettings"
    static let languageKey = "pairshot.language"
    static let themeKey = "pairshot.theme"

    // swiftlint:disable trailing_comma
    private static let registeredDefaults: [String: Any] = [
        UserDefaultsAppSettingsRepository.jpegQualityKey: AppSettingsSnapshot.defaultJpegQuality,
        UserDefaultsAppSettingsRepository.fileNamePrefixKey: "",
        UserDefaultsAppSettingsRepository.defaultOverlayAlphaKey: AppSettingsSnapshot.defaultOverlayAlphaValue,
        UserDefaultsAppSettingsRepository.defaultCompositeLayoutKey: AppSettingsSnapshot.defaultCompositeLayoutFallback,
        UserDefaultsAppSettingsRepository.watermarkEnabledKey: AppSettingsSnapshot.defaultWatermarkEnabled,
        UserDefaultsAppSettingsRepository.languageKey: AppSettingsSnapshot.defaultLanguage.rawValue,
        UserDefaultsAppSettingsRepository.themeKey: AppSettingsSnapshot.defaultTheme.rawValue,
    ]
    // swiftlint:enable trailing_comma

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: Self.registeredDefaults)
    }

    func load() -> AppSettingsSnapshot {
        AppSettingsSnapshot(
            jpegQuality: defaults.double(forKey: Self.jpegQualityKey),
            fileNamePrefix: defaults.string(forKey: Self.fileNamePrefixKey) ?? "",
            defaultOverlayAlpha: defaults.double(forKey: Self.defaultOverlayAlphaKey),
            defaultCompositeLayoutRawValue: defaults.string(forKey: Self.defaultCompositeLayoutKey)
                ?? AppSettingsSnapshot.defaultCompositeLayoutFallback,
            watermarkEnabled: defaults.bool(forKey: Self.watermarkEnabledKey),
            language: decodeLanguage(),
            theme: decodeTheme(),
            watermark: decodeWatermark(),
            combine: decodeCombine()
        )
    }

    func save(_ settings: AppSettingsSnapshot) async throws {
        defaults.set(settings.jpegQuality, forKey: Self.jpegQualityKey)
        defaults.set(settings.fileNamePrefix, forKey: Self.fileNamePrefixKey)
        defaults.set(settings.defaultOverlayAlpha, forKey: Self.defaultOverlayAlphaKey)
        defaults.set(settings.defaultCompositeLayoutRawValue, forKey: Self.defaultCompositeLayoutKey)
        defaults.set(settings.watermarkEnabled, forKey: Self.watermarkEnabledKey)
        defaults.set(settings.language.rawValue, forKey: Self.languageKey)
        defaults.set(settings.theme.rawValue, forKey: Self.themeKey)
        encodeWatermark(settings.watermark)
        encodeCombine(settings.combine)
    }

    func observe() -> AsyncStream<AppSettingsSnapshot> {
        let observed = defaults
        let load: @Sendable () -> AppSettingsSnapshot = { [weak self] in
            self?.load() ?? AppSettingsSnapshot.default
        }
        return AsyncStream { continuation in
            continuation.yield(load())
            let token = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: observed,
                queue: nil
            ) { _ in
                continuation.yield(load())
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(token)
            }
        }
    }

    private func decodeLanguage() -> AppLanguage {
        let raw = defaults.string(forKey: Self.languageKey) ?? AppSettingsSnapshot.defaultLanguage.rawValue
        return AppLanguage(rawValue: raw) ?? AppSettingsSnapshot.defaultLanguage
    }

    private func decodeTheme() -> AppTheme {
        let raw = defaults.string(forKey: Self.themeKey) ?? AppSettingsSnapshot.defaultTheme.rawValue
        return AppTheme(rawValue: raw) ?? AppSettingsSnapshot.defaultTheme
    }

    private func decodeWatermark() -> WatermarkSettings? {
        guard let raw = defaults.string(forKey: Self.watermarkSettingsKey),
              let data = raw.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(WatermarkSettings.self, from: data)
    }

    private func encodeWatermark(_ watermark: WatermarkSettings?) {
        guard let watermark else {
            defaults.removeObject(forKey: Self.watermarkSettingsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(watermark),
              let raw = String(data: data, encoding: .utf8)
        else {
            return
        }
        defaults.set(raw, forKey: Self.watermarkSettingsKey)
    }

    private func decodeCombine() -> CombineSettings? {
        guard let raw = defaults.string(forKey: Self.combineSettingsKey),
              let data = raw.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(CombineSettings.self, from: data)
    }

    private func encodeCombine(_ combine: CombineSettings?) {
        guard let combine else {
            defaults.removeObject(forKey: Self.combineSettingsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(combine),
              let raw = String(data: data, encoding: .utf8)
        else {
            return
        }
        defaults.set(raw, forKey: Self.combineSettingsKey)
    }

    deinit {}
}
