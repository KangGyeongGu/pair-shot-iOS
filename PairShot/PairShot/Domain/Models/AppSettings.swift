import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    var jpegQuality: Double {
        get { defaults.double(forKey: AppSettingsKeys.jpegQuality) }
        set { defaults.set(newValue, forKey: AppSettingsKeys.jpegQuality) }
    }

    var fileNamePrefix: String {
        get {
            let stored = defaults.string(forKey: AppSettingsKeys.fileNamePrefix) ?? ""
            return stored.isEmpty ? AndroidParityDefaults.fileNamePrefix : stored
        }
        set { defaults.set(newValue, forKey: AppSettingsKeys.fileNamePrefix) }
    }

    var defaultOverlayAlpha: Double {
        get { CompositionDefaults.clampAlpha(defaults.double(forKey: AppSettingsKeys.defaultOverlayAlpha)) }
        set { defaults.set(CompositionDefaults.clampAlpha(newValue), forKey: AppSettingsKeys.defaultOverlayAlpha) }
    }

    var defaultCompositeLayout: CompositeLayout {
        get {
            let raw = defaults.string(forKey: AppSettingsKeys.defaultCompositeLayout) ?? ""
            return CompositionDefaults.layout(forRawValue: raw)
        }
        set { defaults.set(newValue.rawValue, forKey: AppSettingsKeys.defaultCompositeLayout) }
    }

    var watermarkEnabled: Bool {
        didSet {
            defaults.set(watermarkEnabled, forKey: AppSettingsKeys.watermarkEnabled)
        }
    }

    var watermarkSettings: WatermarkSettings {
        get {
            if let cached = cachedWatermarkSettings { return cached }
            let decoded = Self.decodeWatermarkSettings(defaults: defaults)
            cachedWatermarkSettings = decoded
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let raw = String(data: data, encoding: .utf8)
            else { return }
            defaults.set(raw, forKey: AppSettingsKeys.watermarkSettings)
            cachedWatermarkSettings = newValue
        }
    }

    var combineSettings: CombineSettings {
        get {
            if let cached = cachedCombineSettings { return cached }
            let decoded = Self.decodeCombineSettings(defaults: defaults)
            cachedCombineSettings = decoded
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let raw = String(data: data, encoding: .utf8)
            else { return }
            defaults.set(raw, forKey: AppSettingsKeys.combineSettings)
            cachedCombineSettings = newValue
        }
    }

    var language: AppLanguage {
        get {
            let raw = defaults.string(forKey: AppSettingsKeys.language) ?? AppLanguage.system.rawValue
            return AppLanguage(rawValue: raw) ?? .system
        }
        set { defaults.set(newValue.rawValue, forKey: AppSettingsKeys.language) }
    }

    var theme: AppTheme {
        get {
            let raw = defaults.string(forKey: AppSettingsKeys.theme) ?? AppTheme.system.rawValue
            return AppTheme(rawValue: raw) ?? .system
        }
        set { defaults.set(newValue.rawValue, forKey: AppSettingsKeys.theme) }
    }

    var cameraGridEnabled: Bool {
        get { defaults.bool(forKey: AppSettingsKeys.cameraGridEnabled) }
        set { defaults.set(newValue, forKey: AppSettingsKeys.cameraGridEnabled) }
    }

    var cameraLevelEnabled: Bool {
        get { defaults.bool(forKey: AppSettingsKeys.cameraLevelEnabled) }
        set { defaults.set(newValue, forKey: AppSettingsKeys.cameraLevelEnabled) }
    }

    var cameraFlashMode: String {
        get {
            let raw =
                defaults.string(forKey: AppSettingsKeys.cameraFlashMode)
                    ?? CameraFlashModePersistence.defaultRawValue
            return CameraFlashModePersistence.normalize(raw)
        }
        set {
            defaults.set(CameraFlashModePersistence.normalize(newValue), forKey: AppSettingsKeys.cameraFlashMode)
        }
    }

    var cameraNightMode: Bool {
        get { defaults.bool(forKey: AppSettingsKeys.cameraNightMode) }
        set { defaults.set(newValue, forKey: AppSettingsKeys.cameraNightMode) }
    }

    var cameraAspectRatio: AspectRatio {
        get {
            let raw =
                defaults.string(forKey: AppSettingsKeys.cameraAspectRatio)
                    ?? AspectRatio.default.rawValue
            return AspectRatio(rawValue: raw) ?? .default
        }
        set { defaults.set(newValue.rawValue, forKey: AppSettingsKeys.cameraAspectRatio) }
    }

    var overlayEnabled: Bool {
        get { defaults.bool(forKey: AppSettingsKeys.overlayEnabled) }
        set { defaults.set(newValue, forKey: AppSettingsKeys.overlayEnabled) }
    }

    var embedGPSInPhoto: Bool {
        get { defaults.bool(forKey: AppSettingsKeys.embedGPSInPhoto) }
        set { defaults.set(newValue, forKey: AppSettingsKeys.embedGPSInPhoto) }
    }

    var homeSortOrder: String {
        didSet {
            let normalized = SortOrderPersistence.normalize(homeSortOrder)
            defaults.set(normalized, forKey: AppSettingsKeys.homeSortOrder)
            if normalized != homeSortOrder {
                homeSortOrder = normalized
            }
        }
    }

    var albumSortOrder: String {
        didSet {
            let normalized = SortOrderPersistence.normalize(albumSortOrder)
            defaults.set(normalized, forKey: AppSettingsKeys.albumSortOrder)
            if normalized != albumSortOrder {
                albumSortOrder = normalized
            }
        }
    }

    var resolvedLocale: Locale {
        language.locale ?? Locale.autoupdatingCurrent
    }

    private let defaults: UserDefaults
    @ObservationIgnored private var cachedWatermarkSettings: WatermarkSettings?
    @ObservationIgnored private var cachedCombineSettings: CombineSettings?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            AppSettingsKeys.jpegQuality: CaptureQualityPreset.high.rawValue,
            AppSettingsKeys.fileNamePrefix: AndroidParityDefaults.fileNamePrefix,
            AppSettingsKeys.defaultOverlayAlpha: CompositionDefaults.fallbackAlpha,
            AppSettingsKeys.defaultCompositeLayout: CompositionDefaults.fallbackLayout.rawValue,
            AppSettingsKeys.language: AppLanguage.system.rawValue,
            AppSettingsKeys.theme: AppTheme.system.rawValue,
            AppSettingsKeys.cameraGridEnabled: false,
            AppSettingsKeys.cameraLevelEnabled: false,
            AppSettingsKeys.cameraFlashMode: CameraFlashModePersistence.defaultRawValue,
            AppSettingsKeys.cameraNightMode: false,
            AppSettingsKeys.cameraAspectRatio: AspectRatio.default.rawValue,
            AppSettingsKeys.overlayEnabled: true,
            AppSettingsKeys.embedGPSInPhoto: true,
            AppSettingsKeys.homeSortOrder: SortOrderPersistence.defaultRawValue,
            AppSettingsKeys.albumSortOrder: SortOrderPersistence.defaultRawValue,
        ])
        watermarkEnabled = defaults.bool(forKey: AppSettingsKeys.watermarkEnabled)
        let storedHome =
            defaults.string(forKey: AppSettingsKeys.homeSortOrder)
                ?? SortOrderPersistence.defaultRawValue
        homeSortOrder = SortOrderPersistence.normalize(storedHome)
        let storedAlbum =
            defaults.string(forKey: AppSettingsKeys.albumSortOrder)
                ?? SortOrderPersistence.defaultRawValue
        albumSortOrder = SortOrderPersistence.normalize(storedAlbum)
    }

    private static func decodeWatermarkSettings(defaults: UserDefaults) -> WatermarkSettings {
        guard let raw = defaults.string(forKey: AppSettingsKeys.watermarkSettings),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(WatermarkSettings.self, from: data)
        else { return .default }
        return decoded
    }

    private static func decodeCombineSettings(defaults: UserDefaults) -> CombineSettings {
        guard let raw = defaults.string(forKey: AppSettingsKeys.combineSettings),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(CombineSettings.self, from: data)
        else { return .default }
        return decoded
    }
}

nonisolated enum CameraFlashModePersistence {
    static let off = "OFF"
    static let auto = "AUTO"
    static let on = "ON"
    static let torch = "TORCH"
    static let defaultRawValue = off
    static let allowedValues: Set<String> = [off, auto, on, torch]

    static func normalize(_ raw: String) -> String {
        let upper = raw.uppercased()
        return allowedValues.contains(upper) ? upper : defaultRawValue
    }
}

nonisolated enum SortOrderPersistence {
    static let descending = "DESC"
    static let ascending = "ASC"
    static let defaultRawValue = descending
    static let allowedValues: Set<String> = [descending, ascending]

    static func normalize(_ raw: String) -> String {
        let upper = raw.uppercased()
        return allowedValues.contains(upper) ? upper : defaultRawValue
    }
}

nonisolated enum AndroidParityDefaults {
    static let fileNamePrefix: String = "PAIRSHOT"
}

nonisolated enum CompositionDefaults {
    static let alphaRange: ClosedRange<Double> = 0.0 ... 1.0
    static let fallbackAlpha: Double = 0.35
    static let fallbackLayout: CompositeLayout = .horizontal

    static func clampAlpha(_ value: Double) -> Double {
        guard value.isFinite else { return fallbackAlpha }
        return max(alphaRange.lowerBound, min(alphaRange.upperBound, value))
    }

    static func layout(forRawValue raw: String) -> CompositeLayout {
        CompositeLayout(rawValue: raw) ?? fallbackLayout
    }
}

nonisolated enum CaptureQualityPreset: Double, CaseIterable, Identifiable {
    case low = 0.6
    case standard = 0.8
    case high = 0.95

    var id: Double {
        rawValue
    }

    var label: String {
        switch self {
            case .low: String(localized: "image_quality_low")
            case .standard: String(localized: "image_quality_standard")
            case .high: String(localized: "image_quality_high")
        }
    }

    static func nearest(to quality: Double) -> Self {
        allCases.min(by: { abs($0.rawValue - quality) < abs($1.rawValue - quality) }) ?? .standard
    }
}

nonisolated enum FileNamePrefixValidator {
    static let maxLength = 32

    static let forbiddenCharacters: CharacterSet = {
        var set = CharacterSet(charactersIn: "/\\:?*\"<>|")
        set.formUnion(.controlCharacters)
        set.formUnion(.newlines)
        return set
    }()

    static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let scrubbed = trimmed.unicodeScalars
            .filter { !forbiddenCharacters.contains($0) }
            .map(String.init)
            .joined()
        if scrubbed.count <= maxLength {
            return scrubbed
        }
        return String(scrubbed.prefix(maxLength))
    }
}
