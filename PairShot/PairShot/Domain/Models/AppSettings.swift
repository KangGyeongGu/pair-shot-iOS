import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppSettings {
    var jpegQuality: Double {
        get { defaults.double(forKey: Self.jpegQualityKey) }
        set { defaults.set(newValue, forKey: Self.jpegQualityKey) }
    }

    var fileNamePrefix: String {
        get {
            let stored = defaults.string(forKey: Self.fileNamePrefixKey) ?? ""
            return stored.isEmpty ? AndroidParityDefaults.fileNamePrefix : stored
        }
        set { defaults.set(newValue, forKey: Self.fileNamePrefixKey) }
    }

    var defaultOverlayAlpha: Double {
        get { CompositionDefaults.clampAlpha(defaults.double(forKey: Self.defaultOverlayAlphaKey)) }
        set { defaults.set(CompositionDefaults.clampAlpha(newValue), forKey: Self.defaultOverlayAlphaKey) }
    }

    var defaultCompositeLayout: CompositeLayout {
        get {
            let raw = defaults.string(forKey: Self.defaultCompositeLayoutKey) ?? ""
            return CompositionDefaults.layout(forRawValue: raw)
        }
        set { defaults.set(newValue.rawValue, forKey: Self.defaultCompositeLayoutKey) }
    }

    var watermarkEnabled: Bool {
        didSet {
            defaults.set(watermarkEnabled, forKey: WatermarkOverlay.userDefaultsKey)
        }
    }

    var watermarkSettings: WatermarkSettings {
        get {
            guard let raw = defaults.string(forKey: Self.watermarkSettingsKey),
                  let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(WatermarkSettings.self, from: data)
            else { return .default }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let raw = String(data: data, encoding: .utf8)
            else { return }
            defaults.set(raw, forKey: Self.watermarkSettingsKey)
        }
    }

    var combineSettings: CombineSettings {
        get {
            guard let raw = defaults.string(forKey: Self.combineSettingsKey),
                  let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(CombineSettings.self, from: data)
            else { return .default }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let raw = String(data: data, encoding: .utf8)
            else { return }
            defaults.set(raw, forKey: Self.combineSettingsKey)
        }
    }

    var language: AppLanguage {
        get {
            let raw = defaults.string(forKey: Self.languageKey) ?? AppLanguage.system.rawValue
            return AppLanguage(rawValue: raw) ?? .system
        }
        set { defaults.set(newValue.rawValue, forKey: Self.languageKey) }
    }

    var theme: AppTheme {
        get {
            let raw = defaults.string(forKey: Self.themeKey) ?? AppTheme.system.rawValue
            return AppTheme(rawValue: raw) ?? .system
        }
        set { defaults.set(newValue.rawValue, forKey: Self.themeKey) }
    }

    var resolvedLocale: Locale {
        language.locale ?? Locale.autoupdatingCurrent
    }

    var resolvedColorScheme: ColorScheme? {
        theme.preferredColorScheme
    }

    static let jpegQualityKey = "pairshot.jpegQuality"
    static let fileNamePrefixKey = "pairshot.fileNamePrefix"
    static let defaultOverlayAlphaKey = "pairshot.defaultOverlayAlpha"
    static let defaultCompositeLayoutKey = "pairshot.defaultCompositeLayout"
    static let watermarkSettingsKey = "pairshot.watermarkSettings"
    static let combineSettingsKey = "pairshot.combineSettings"
    static let languageKey = "pairshot.language"
    static let themeKey = "pairshot.theme"
    static let shared = AppSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Self.jpegQualityKey: CaptureQualityPreset.high.rawValue,
            Self.fileNamePrefixKey: AndroidParityDefaults.fileNamePrefix,
            Self.defaultOverlayAlphaKey: CompositionDefaults.fallbackAlpha,
            Self.defaultCompositeLayoutKey: CompositionDefaults.fallbackLayout.rawValue,
            WatermarkOverlay.userDefaultsKey: WatermarkOverlay.defaultEnabled,
            Self.languageKey: AppLanguage.system.rawValue,
            Self.themeKey: AppTheme.system.rawValue,
        ])
        watermarkEnabled = defaults.bool(forKey: WatermarkOverlay.userDefaultsKey)
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
