import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class SettingsViewModel {
    enum Event {
        case dismiss
    }

    enum GateResult: Equatable {
        case proceed
        case adNotReady
        case userClosed
        case failed(reason: String)
    }

    let appSettings: AppSettings
    let appSettingsRepo: AppSettingsRepository
    let storage: PhotoStorageService
    let events: AsyncStream<Event>

    var showCacheClearConfirm: Bool = false
    var showWatermarkGateDialog: Bool = false
    var showCombineGateDialog: Bool = false
    var showLanguageRestartAlert: Bool = false
    var shouldPulseWatermark: Bool = false
    var shouldPulseCombine: Bool = false
    var lastGateFailureReason: String?

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

    var imageQualityPreset: CaptureQualityPreset {
        CaptureQualityPreset.nearest(to: appSettings.jpegQuality)
    }

    var imageQualityValueText: String {
        let preset = imageQualityPreset
        let percent = Int((preset.rawValue * 100).rounded())
        return "\(preset.label) (\(percent)%)"
    }

    var overlayAlphaEnabled: Bool = false {
        didSet {
            if overlayAlphaEnabled {
                if appSettings.defaultOverlayAlpha <= 0 {
                    appSettings.defaultOverlayAlpha = CompositionDefaults.fallbackAlpha
                }
                overlayAlphaValue = appSettings.defaultOverlayAlpha
            } else {
                appSettings.defaultOverlayAlpha = 0
                overlayAlphaValue = 0
            }
        }
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
        let snapshot = appSettingsRepo.load()
        guard let watermark = snapshot.watermark else { return true }
        switch watermark.type {
            case .text:
                return watermark.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            case .logo:
                return watermark.logoImageData == nil
        }
    }

    var photoStorageText: String {
        if let photoStorageBytes {
            return SettingsStorageFormatter.formatBytes(photoStorageBytes)
        }
        return isCalculatingStorage ? String(localized: "settings_calculating_short") : "—"
    }

    var cacheText: String {
        if isClearingCache {
            return String(localized: "settings_deleting_short")
        }
        if let cacheBytes {
            return SettingsStorageFormatter.formatBytes(cacheBytes)
        }
        return isCalculatingStorage ? String(localized: "settings_calculating_short") : "—"
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
        overlayAlphaValue = CompositionDefaults.clampAlpha(appSettings.defaultOverlayAlpha)
        overlayAlphaEnabled = appSettings.defaultOverlayAlpha > 0
    }

    func dismiss() {
        eventsContinuation.yield(.dismiss)
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

    func requestWatermarkGate(
        rewardedManager: RewardedAdManager,
        adFreeStore: AdFreeStore
    ) -> Bool {
        requestGate(
            unlockID: .watermarkSettings,
            rewardedManager: rewardedManager,
            adFreeStore: adFreeStore,
            dialogFlag: \.showWatermarkGateDialog
        )
    }

    func requestCombineGate(
        rewardedManager: RewardedAdManager,
        adFreeStore: AdFreeStore
    ) -> Bool {
        requestGate(
            unlockID: .compositionSettings,
            rewardedManager: rewardedManager,
            adFreeStore: adFreeStore,
            dialogFlag: \.showCombineGateDialog
        )
    }

    func confirmWatermarkGateAd(
        rewardedManager: RewardedAdManager,
        adFreeStore: AdFreeStore,
        coordinator: FullscreenAdCoordinator,
        rootViewController: UIViewController?
    ) async -> GateResult {
        await presentGateAd(
            unlockID: .watermarkSettings,
            rewardedManager: rewardedManager,
            adFreeStore: adFreeStore,
            coordinator: coordinator,
            rootViewController: rootViewController
        )
    }

    func confirmCombineGateAd(
        rewardedManager: RewardedAdManager,
        adFreeStore: AdFreeStore,
        coordinator: FullscreenAdCoordinator,
        rootViewController: UIViewController?
    ) async -> GateResult {
        await presentGateAd(
            unlockID: .compositionSettings,
            rewardedManager: rewardedManager,
            adFreeStore: adFreeStore,
            coordinator: coordinator,
            rootViewController: rootViewController
        )
    }

    private func requestGate(
        unlockID: RewardedAdManager.UnlockID,
        rewardedManager: RewardedAdManager,
        adFreeStore: AdFreeStore,
        dialogFlag: ReferenceWritableKeyPath<SettingsViewModel, Bool>
    ) -> Bool {
        lastGateFailureReason = nil
        if !RewardedSessionGate.shouldShowGate(
            unlockID: unlockID,
            sessionUnlocks: rewardedManager.sessionUnlocks,
            isAdFree: adFreeStore.isAdFree
        ) {
            return true
        }
        rewardedManager.loadIfNeeded(adFreeStore: adFreeStore)
        self[keyPath: dialogFlag] = true
        return false
    }

    private func presentGateAd(
        unlockID: RewardedAdManager.UnlockID,
        rewardedManager: RewardedAdManager,
        adFreeStore: AdFreeStore,
        coordinator: FullscreenAdCoordinator,
        rootViewController: UIViewController?
    ) async -> GateResult {
        lastGateFailureReason = nil
        if !RewardedSessionGate.shouldShowGate(
            unlockID: unlockID,
            sessionUnlocks: rewardedManager.sessionUnlocks,
            isAdFree: adFreeStore.isAdFree
        ) {
            return .proceed
        }
        if !rewardedManager.isLoaded {
            rewardedManager.loadIfNeeded(adFreeStore: adFreeStore)
            lastGateFailureReason = String(localized: "rewarded_gate_load_failed")
            return .adNotReady
        }
        let outcome = await rewardedManager.presentForReward(
            unlockID,
            from: rootViewController,
            coordinator: coordinator,
            adFreeStore: adFreeStore
        )
        return mapOutcome(outcome)
    }

    // swiftlint:disable switch_case_alignment
    private func mapOutcome(_ outcome: RewardedAdManager.RewardOutcome) -> GateResult {
        switch outcome {
            case .granted, .skipped:
                return .proceed

            case .userClosed:
                lastGateFailureReason = String(localized: "rewarded_gate_failure_not_completed")
                return .userClosed

            case let .failed(reason):
                lastGateFailureReason = String(
                    format: String(localized: "rewarded_gate_failure_show_failed_template"),
                    reason
                )
                return .failed(reason: reason)
        }
    }

    // swiftlint:enable switch_case_alignment

    deinit {}
}

extension SettingsViewModel {
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
