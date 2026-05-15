import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    let appSettings: AppSettings
    let membership: Membership?

    var showLanguageRestartAlert: Bool = false
    var shouldPulseWatermark: Bool = false
    var shouldPulseCombine: Bool = false
    var showWatermarkGateDialog: Bool = false
    var showCombineGateDialog: Bool = false
    var lastGateFailureReason: String?

    var appVersionText: String {
        let version = SettingsBundleMetadata.appVersionLabel
        let build = SettingsBundleMetadata.buildNumberLabel
        if version == "—", build == "—" { return "—" }
        return "\(version) (\(build))"
    }

    var languageDisplayText: String {
        appSettings.language.displayName
    }

    var themeDisplayText: String {
        appSettings.theme.displayName
    }

    var watermarkEnabled: Bool {
        get { appSettings.watermarkEnabled }
        set { appSettings.watermarkEnabled = newValue }
    }

    var embedGPSInPhoto: Bool {
        get { appSettings.embedGPSInPhoto }
        set { appSettings.embedGPSInPhoto = newValue }
    }

    var imageQualityPreset: CaptureQualityPreset {
        CaptureQualityPreset.nearest(to: appSettings.jpegQuality)
    }

    var imageQualityValueText: String {
        let preset = imageQualityPreset
        let percent = Int((preset.rawValue * 100).rounded())
        return "\(preset.label) (\(percent)%)"
    }

    var overlayAlphaEnabled: Bool = false {
        didSet { appSettings.overlayEnabled = overlayAlphaEnabled }
    }

    var overlayAlphaValue: Double = 0 {
        didSet {
            let clamped = CompositionDefaults.clampAlpha(overlayAlphaValue)
            if appSettings.defaultOverlayAlpha != clamped {
                appSettings.defaultOverlayAlpha = clamped
            }
        }
    }

    var overlayAlphaPercentText: String {
        let pct = Int((overlayAlphaValue * 100).rounded())
        return "\(pct)%"
    }

    var fileNamePrefixDisplay: String {
        let safe = FileNamePrefixValidator.sanitize(appSettings.fileNamePrefix)
        if safe.isEmpty {
            return String(localized: "settings_file_name_prefix_none")
        }
        return safe
    }

    var watermarkSettingsBlank: Bool {
        appSettings.watermarkSettings.isBlank
    }

    init(
        appSettings: AppSettings,
        membership: Membership? = nil
    ) {
        self.appSettings = appSettings
        self.membership = membership
        overlayAlphaValue = CompositionDefaults.clampAlpha(appSettings.defaultOverlayAlpha)
        overlayAlphaEnabled = appSettings.overlayEnabled
    }

    func setLanguage(_ language: AppLanguage) {
        let previous = appSettings.language
        appSettings.language = language
        AppLanguageBundleSync.apply(language)
        if previous != language {
            showLanguageRestartAlert = true
        }
    }

    func setTheme(_ theme: AppTheme) {
        appSettings.theme = theme
    }

    func setImageQuality(_ preset: CaptureQualityPreset) {
        appSettings.jpegQuality = preset.rawValue
    }
}

extension SettingsViewModel {
    func triggerPulse(_ flag: ReferenceWritableKeyPath<SettingsViewModel, Bool>) {
        self[keyPath: flag] = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            self[keyPath: flag] = false
        }
    }
}

enum SettingsBundleMetadata {
    static var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return version ?? "—"
    }

    static var buildNumberLabel: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return build ?? "—"
    }
}
