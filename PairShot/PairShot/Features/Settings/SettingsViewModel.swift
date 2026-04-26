import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    enum Event {
        case dismiss
    }

    let appSettings: AppSettings
    let appSettingsRepo: AppSettingsRepository
    let storage: PhotoStorageService
    let events: AsyncStream<Event>

    var showLanguagePicker: Bool = false
    var showThemePicker: Bool = false
    var showCacheClearConfirm: Bool = false
    var shouldPulseWatermark: Bool = false
    var shouldPulseCombine: Bool = false

    private(set) var photoStorageBytes: Int64?
    private(set) var cacheBytes: Int64?
    private(set) var lastStorageError: String?
    private(set) var isCalculatingStorage: Bool = false
    private(set) var isClearingCache: Bool = false

    private let eventsContinuation: AsyncStream<Event>.Continuation

    var captureSummary: String {
        appSettings.captureSummary
    }

    var compositionSummary: String {
        appSettings.compositionSummary
    }

    var appVersionLabel: String {
        SettingsBundleMetadata.appVersionLabel
    }

    var buildNumberLabel: String {
        SettingsBundleMetadata.buildNumberLabel
    }

    var appVersionText: String {
        let version = SettingsBundleMetadata.appVersionLabel
        let build = SettingsBundleMetadata.buildNumberLabel
        if version == "—", build == "—" { return "—" }
        return String(format: String(localized: "%@ (%@)"), version, build)
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

    var watermarkSettingsBlank: Bool {
        let snapshot = appSettingsRepo.load()
        guard let watermark = snapshot.watermark else { return true }
        return watermark == WatermarkSettings.default
    }

    var photoStorageText: String {
        if let photoStorageBytes {
            return SettingsStorageFormatter.formatBytes(photoStorageBytes)
        }
        return isCalculatingStorage ? String(localized: "계산 중…") : "—"
    }

    var cacheText: String {
        if isClearingCache {
            return String(localized: "삭제 중…")
        }
        if let cacheBytes {
            return SettingsStorageFormatter.formatBytes(cacheBytes)
        }
        return isCalculatingStorage ? String(localized: "계산 중…") : "—"
    }

    init(
        appSettings: AppSettings,
        appSettingsRepo: AppSettingsRepository,
        storage: PhotoStorageService
    ) {
        self.appSettings = appSettings
        self.appSettingsRepo = appSettingsRepo
        self.storage = storage
        var continuation: AsyncStream<Event>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventsContinuation = continuation
    }

    func dismiss() {
        eventsContinuation.yield(.dismiss)
    }

    func setLanguage(_ language: AppLanguage) {
        appSettings.language = language
    }

    func setTheme(_ theme: AppTheme) {
        appSettings.theme = theme
    }

    func triggerWatermarkPulse() {
        shouldPulseWatermark = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            shouldPulseWatermark = false
        }
    }

    func triggerCombinePulse() {
        shouldPulseCombine = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            shouldPulseCombine = false
        }
    }

    func refreshStorageInfo() async {
        guard !isCalculatingStorage else { return }
        isCalculatingStorage = true
        lastStorageError = nil
        defer { isCalculatingStorage = false }
        let storageRef = storage
        do {
            let photos = try await Task.detached(priority: .userInitiated) {
                try storageRef.photosDirectorySize()
            }.value
            let cache = try await Task.detached(priority: .userInitiated) {
                try storageRef.thumbnailsDirectorySize()
            }.value
            photoStorageBytes = photos
            cacheBytes = cache
        } catch {
            lastStorageError = error.localizedDescription
        }
    }

    func clearCache() async {
        guard !isClearingCache else { return }
        isClearingCache = true
        defer { isClearingCache = false }
        let storageRef = storage
        do {
            try await Task.detached(priority: .userInitiated) {
                try storageRef.clearAllThumbnails()
            }.value
            HapticService.shared.notify(.success)
            await refreshStorageInfo()
        } catch {
            lastStorageError = error.localizedDescription
        }
    }

    deinit {}
}

enum SettingsStorageFormatter {
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = true
        return formatter.string(fromByteCount: max(0, bytes))
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
