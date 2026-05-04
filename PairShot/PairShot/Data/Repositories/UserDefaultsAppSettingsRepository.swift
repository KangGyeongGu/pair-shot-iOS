import Foundation

nonisolated final class UserDefaultsAppSettingsRepository: AppSettingsRepository, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: Self.makeRegisteredDefaults())
    }

    private static func makeRegisteredDefaults() -> [String: Any] {
        [
            AppSettingsKeys.jpegQuality: AppSettingsSnapshot.defaultJpegQuality,
            AppSettingsKeys.fileNamePrefix: AppSettingsSnapshot.defaultFileNamePrefix,
            AppSettingsKeys.defaultOverlayAlpha: AppSettingsSnapshot.defaultOverlayAlphaValue,
            AppSettingsKeys.defaultCompositeLayout: AppSettingsSnapshot.defaultCompositeLayoutFallback,
            AppSettingsKeys.watermarkEnabled: AppSettingsSnapshot.defaultWatermarkEnabled,
            AppSettingsKeys.language: AppSettingsSnapshot.defaultLanguage.rawValue,
            AppSettingsKeys.theme: AppSettingsSnapshot.defaultTheme.rawValue,
            AppSettingsKeys.cameraGridEnabled: AppSettingsHandoffDefaults.cameraGridEnabled,
            AppSettingsKeys.cameraLevelEnabled: AppSettingsHandoffDefaults.cameraLevelEnabled,
            AppSettingsKeys.cameraFlashMode: AppSettingsHandoffDefaults.cameraFlashMode,
            AppSettingsKeys.cameraNightMode: AppSettingsHandoffDefaults.cameraNightMode,
            AppSettingsKeys.overlayEnabled: AppSettingsHandoffDefaults.overlayEnabled,
            AppSettingsKeys.homeSortOrder: AppSettingsHandoffDefaults.homeSortOrder,
            AppSettingsKeys.albumSortOrder: AppSettingsHandoffDefaults.albumSortOrder,
        ]
    }

    func load() -> AppSettingsSnapshot {
        AppSettingsSnapshot(
            jpegQuality: defaults.double(forKey: AppSettingsKeys.jpegQuality),
            fileNamePrefix: defaults.string(forKey: AppSettingsKeys.fileNamePrefix) ?? "",
            defaultOverlayAlpha: defaults.double(forKey: AppSettingsKeys.defaultOverlayAlpha),
            defaultCompositeLayoutRawValue: defaults.string(forKey: AppSettingsKeys.defaultCompositeLayout)
                ?? AppSettingsSnapshot.defaultCompositeLayoutFallback,
            watermarkEnabled: defaults.bool(forKey: AppSettingsKeys.watermarkEnabled),
            language: decodeLanguage(),
            theme: decodeTheme(),
            watermark: decodeWatermark(),
            combine: decodeCombine()
        )
    }

    func save(_ settings: AppSettingsSnapshot) async throws {
        defaults.set(settings.jpegQuality, forKey: AppSettingsKeys.jpegQuality)
        defaults.set(settings.fileNamePrefix, forKey: AppSettingsKeys.fileNamePrefix)
        defaults.set(settings.defaultOverlayAlpha, forKey: AppSettingsKeys.defaultOverlayAlpha)
        defaults.set(settings.defaultCompositeLayoutRawValue, forKey: AppSettingsKeys.defaultCompositeLayout)
        defaults.set(settings.watermarkEnabled, forKey: AppSettingsKeys.watermarkEnabled)
        defaults.set(settings.language.rawValue, forKey: AppSettingsKeys.language)
        defaults.set(settings.theme.rawValue, forKey: AppSettingsKeys.theme)
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
            let tokenBox = NotificationObserverTokenBox()
            tokenBox.token = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: observed,
                queue: nil
            ) { _ in
                continuation.yield(load())
            }
            continuation.onTermination = { _ in
                if let token = tokenBox.token {
                    NotificationCenter.default.removeObserver(token)
                }
            }
        }
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
        return try? JSONDecoder().decode(WatermarkSettings.self, from: data)
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

nonisolated private final class NotificationObserverTokenBox: @unchecked Sendable {
    var token: (any NSObjectProtocol)?
    init() {}
}

nonisolated enum AppSettingsHandoffDefaults {
    static let cameraGridEnabled: Bool = false
    static let cameraLevelEnabled: Bool = false
    static let cameraFlashMode: String = "OFF"
    static let cameraNightMode: Bool = false
    static let overlayEnabled: Bool = true
    static let homeSortOrder: String = "DESC"
    static let albumSortOrder: String = "DESC"
}
