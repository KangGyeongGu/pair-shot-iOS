import Foundation
import Observation
import OSLog
import Photos
import SwiftData
import UIKit

struct ExportShareItems: Identifiable {
    let id = UUID()
    let values: [Any]
}

enum ExportSettingsRedirectTarget: Equatable {
    case watermarkSettings
    case combineSettings
}

@MainActor
@Observable
final class ExportSettingsViewModel {
    enum Event {
        case dismiss
    }

    enum GateResult: Equatable {
        case proceed
        case adNotReady
        case userClosed
        case failed(reason: String)
    }

    let pairIds: [UUID]
    let albumId: UUID?
    let events: AsyncStream<Event>

    var includeCombined: Bool {
        didSet { preferences.includeCombined = includeCombined }
    }

    var includeBefore: Bool {
        didSet { preferences.includeBefore = includeBefore }
    }

    var includeAfter: Bool {
        didSet { preferences.includeAfter = includeAfter }
    }

    var format: ExportFormat {
        didSet { preferences.format = format }
    }

    var applyWatermark: Bool {
        didSet { preferences.applyWatermark = applyWatermark }
    }

    var applyCombineSettings: Bool {
        didSet { preferences.applyCombineSettings = applyCombineSettings }
    }

    var isExporting: Bool = false
    var errorMessage: LocalizedStringResource?
    var shareItems: ExportShareItems?
    var zipExportItem: DocumentExporterItem?
    var showWatermarkGateDialog: Bool = false
    var showCombineGateDialog: Bool = false
    var lastGateFailureReason: String?

    private var zipSaveProgress: SnackbarProgressHandle?

    var hasAnyInclude: Bool {
        includeCombined || includeBefore || includeAfter
    }

    var canExecute: Bool {
        !isExporting && hasAnyInclude && !pairIds.isEmpty
    }

    private let pairRepo: PhotoPairRepository
    private let photoLibrary: PhotoLibraryService
    private let exportPairs: ExportPairsUseCase
    private let photoLibraryExporter: PhotoLibraryExport
    private let snackbarQueue: SnackbarQueue
    private let tempDirectoryProvider: @Sendable () -> URL
    private let eventsContinuation: AsyncStream<Event>.Continuation
    private let appSettings: AppSettings?
    private var preferences: ExportPreferences
    private let interstitialAdManager: InterstitialAdManager?
    private let adFreeStore: AdFreeStore?
    private let fullscreenAdCoordinator: FullscreenAdCoordinator?
    private let modelContainer: ModelContainer?

    private var pendingZipURL: URL?

    init(
        pairIds: [UUID],
        albumId: UUID?,
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        exportPairs: ExportPairsUseCase,
        photoLibraryExporter: PhotoLibraryExport,
        snackbarQueue: SnackbarQueue,
        tempDirectoryProvider: @escaping @Sendable () -> URL = { FileManager.default.temporaryDirectory },
        preferences: ExportPreferences = ExportPreferences(),
        appSettings: AppSettings? = nil,
        interstitialAdManager: InterstitialAdManager? = nil,
        adFreeStore: AdFreeStore? = nil,
        fullscreenAdCoordinator: FullscreenAdCoordinator? = nil,
        modelContainer: ModelContainer? = nil
    ) {
        self.pairIds = pairIds
        self.albumId = albumId
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.exportPairs = exportPairs
        self.photoLibraryExporter = photoLibraryExporter
        self.snackbarQueue = snackbarQueue
        self.tempDirectoryProvider = tempDirectoryProvider
        self.preferences = preferences
        self.appSettings = appSettings
        self.interstitialAdManager = interstitialAdManager
        self.adFreeStore = adFreeStore
        self.fullscreenAdCoordinator = fullscreenAdCoordinator
        self.modelContainer = modelContainer
        includeCombined = preferences.includeCombined
        includeBefore = preferences.includeBefore
        includeAfter = preferences.includeAfter
        format = preferences.format
        applyWatermark = preferences.applyWatermark
        applyCombineSettings = preferences.applyCombineSettings
        var continuation: AsyncStream<Event>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventsContinuation = continuation
    }

    func cleanupPendingZip() {
        guard let url = pendingZipURL else { return }
        pendingZipURL = nil
        try? FileManager.default.removeItem(at: url)
    }

    func clearShareItems() {
        shareItems = nil
        cleanupPendingZip()
        eventsContinuation.yield(.dismiss)
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
        dialogFlag: ReferenceWritableKeyPath<ExportSettingsViewModel, Bool>
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

    func share() async {
        guard canExecute else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            adFreeStore: adFreeStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performShare()
        }
    }

    func saveToDevice() async {
        guard canExecute else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            adFreeStore: adFreeStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performSaveToDevice()
        }
    }

    private func performShare() async {
        isExporting = true
        defer { isExporting = false }
        let token = "export-share-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            "snackbar_progress_share",
            token: token,
            initialValue: 0
        )
        do {
            switch format {
                case .zip:
                    snackbarQueue.updateProgress(handle, value: 0.3)
                    let url = try await exportPairs(
                        ids: pairIds,
                        selection: makeSelection(),
                        renderOptions: makeRenderOptions(),
                        tempDirectory: tempDirectoryProvider()
                    )
                    pendingZipURL = url
                    snackbarQueue.completeProgress(handle, finalMessage: nil)
                    shareItems = ExportShareItems(values: [url])

                case .individualImages:
                    snackbarQueue.updateProgress(handle, value: 0.3)
                    let urls = try await collectIndividualSourceURLs()
                    guard !urls.isEmpty else {
                        snackbarQueue.cancelProgress(handle)
                        errorMessage = "snackbar_error_share_failed"
                        return
                    }
                    snackbarQueue.completeProgress(handle, finalMessage: nil)
                    shareItems = ExportShareItems(values: urls)
            }
        } catch {
            snackbarQueue.cancelProgress(handle)
            errorMessage = "snackbar_error_share_failed"
        }
    }

    private func performSaveToDevice() async {
        isExporting = true
        defer { isExporting = false }
        let token = "export-save-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            "snackbar_progress_save_to_device",
            token: token,
            initialValue: 0
        )
        switch format {
            case .individualImages:
                await saveImagesToPhotoLibrary(progress: handle)

            case .zip:
                await saveZipToTemporaryAndNotify(progress: handle)
        }
    }

    private func saveImagesToPhotoLibrary(progress: SnackbarProgressHandle) async {
        let status = await photoLibraryExporter.authorize()
        guard status == .authorized || status == .limited else {
            snackbarQueue.cancelProgress(progress)
            errorMessage = "snackbar_error_save_failed"
            return
        }
        var saved = 0
        var processed = 0
        let now = Date()
        let renderOptions = makeRenderOptions()
        let selection = makeSelection()
        do {
            let pairs = try await loadPairs()
            let allEntries: [(pair: PhotoPair, entry: ExportSelection.Entry)] = pairs.flatMap { pair in
                ExportSelection.relativePaths(for: pair, selection: selection, now: now)
                    .map { (pair: pair, entry: $0) }
            }
            let total = max(1, allEntries.count)
            for item in allEntries {
                guard let data = await ExportEntryRenderer.render(
                    entry: item.entry,
                    pair: item.pair,
                    photoLibrary: photoLibrary,
                    appSettings: appSettings,
                    renderOptions: renderOptions,
                    now: now
                ) else {
                    processed += 1
                    snackbarQueue.updateProgress(progress, value: Double(processed) / Double(total))
                    continue
                }
                let identifier = try await photoLibraryExporter.saveImageData(data, type: .photo)
                recordExportHistory(
                    identifier: identifier,
                    pair: item.pair,
                    entry: item.entry,
                    renderOptions: renderOptions
                )
                saved += 1
                processed += 1
                snackbarQueue.updateProgress(progress, value: Double(processed) / Double(total))
            }
        } catch {
            snackbarQueue.cancelProgress(progress)
            errorMessage = "snackbar_error_save_failed"
            return
        }
        if saved == 0 {
            snackbarQueue.completeProgress(
                progress,
                finalMessage: "snackbar_warning_nothing_to_save",
                finalVariant: .warning
            )
        } else {
            snackbarQueue.completeProgress(
                progress,
                finalMessage: "snackbar_success_saved_to_device",
                finalVariant: .success
            )
        }
        eventsContinuation.yield(.dismiss)
    }

    private func saveZipToTemporaryAndNotify(progress: SnackbarProgressHandle) async {
        do {
            snackbarQueue.updateProgress(progress, value: 0.3)
            let url = try await exportPairs(
                ids: pairIds,
                selection: makeSelection(),
                renderOptions: makeRenderOptions(),
                tempDirectory: tempDirectoryProvider()
            )
            pendingZipURL = url
            snackbarQueue.updateProgress(progress, value: 1.0)
            zipSaveProgress = progress
            zipExportItem = DocumentExporterItem(url: url)
        } catch {
            snackbarQueue.cancelProgress(progress)
            errorMessage = "snackbar_error_save_failed"
        }
    }

    func handleZipExportCompleted(_ saved: Bool) {
        zipExportItem = nil
        if let progress = zipSaveProgress {
            zipSaveProgress = nil
            if saved {
                snackbarQueue.completeProgress(
                    progress,
                    finalMessage: "snackbar_success_saved_zip",
                    finalVariant: .success
                )
            } else {
                snackbarQueue.cancelProgress(progress)
            }
        }
        cleanupPendingZip()
        if saved {
            eventsContinuation.yield(.dismiss)
        }
    }

    private func collectIndividualSourceURLs() async throws -> [URL] {
        let pairs = try await loadPairs()
        let selection = makeSelection()
        let renderOptions = makeRenderOptions()
        let tempDir = tempDirectoryProvider()
        var urls: [URL] = []
        let now = Date()
        for pair in pairs {
            let entries = ExportSelection.relativePaths(for: pair, selection: selection, now: now)
            for entry in entries {
                guard let data = await ExportEntryRenderer.render(
                    entry: entry,
                    pair: pair,
                    photoLibrary: photoLibrary,
                    appSettings: appSettings,
                    renderOptions: renderOptions,
                    now: now
                ) else { continue }
                let fileName = ExportTempFileWriter.sanitizedName(from: entry.relativeName)
                if let url = ExportTempFileWriter.write(
                    data: data,
                    fileName: fileName,
                    tempDirectory: tempDir
                ) {
                    urls.append(url)
                }
            }
        }
        return urls
    }

    private func loadPairs() async throws -> [PhotoPair] {
        var resolved: [PhotoPair] = []
        for id in pairIds {
            if let pair = try await pairRepo.fetch(id: id) {
                resolved.append(pair)
            }
        }
        return resolved
    }

    private func recordExportHistory(
        identifier: String,
        pair: PhotoPair,
        entry: ExportSelection.Entry,
        renderOptions: ExportRenderOptions
    ) {
        guard let modelContainer else { return }
        guard let kind = ExportHistoryKindResolver.resolve(
            entryKind: entry.kind,
            renderOptions: renderOptions,
            appSettings: appSettings
        ) else { return }
        let context = modelContainer.mainContext
        let pairId = pair.id
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { $0.id == pairId }
        )
        let pairEntity = try? context.fetch(descriptor).first
        let record = ExportHistoryEntity(
            kind: kind,
            photoLocalIdentifier: identifier,
            pair: pairEntity
        )
        context.insert(record)
        do {
            try context.save()
        } catch {
            AppLogger.storage.error(
                "ExportHistory persist failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func makeSelection() -> ExportContents {
        ExportContents(
            includeCombined: includeCombined,
            includeBefore: includeBefore,
            includeAfter: includeAfter
        )
    }

    private func makeRenderOptions() -> ExportRenderOptions {
        ExportRenderOptions(
            applyCombineSettings: applyCombineSettings,
            applyWatermark: applyWatermark
        )
    }
}

final nonisolated class ExportPreferences: @unchecked Sendable {
    static let includeCombinedKey = "pairshot.exportIncludeCombined"
    static let includeBeforeKey = "pairshot.exportIncludeBefore"
    static let includeAfterKey = "pairshot.exportIncludeAfter"
    static let formatKey = "pairshot.exportFormat"
    static let applyWatermarkKey = "pairshot.exportApplyWatermark"
    static let applyCombineKey = "pairshot.exportApplyCombine"

    private let defaults: UserDefaults

    var includeCombined: Bool {
        get { defaults.bool(forKey: Self.includeCombinedKey) }
        set { defaults.set(newValue, forKey: Self.includeCombinedKey) }
    }

    var includeBefore: Bool {
        get { defaults.bool(forKey: Self.includeBeforeKey) }
        set { defaults.set(newValue, forKey: Self.includeBeforeKey) }
    }

    var includeAfter: Bool {
        get { defaults.bool(forKey: Self.includeAfterKey) }
        set { defaults.set(newValue, forKey: Self.includeAfterKey) }
    }

    var format: ExportFormat {
        get {
            let raw = defaults.string(forKey: Self.formatKey) ?? ExportFormat.individualImages.rawValue
            return ExportFormat(rawValue: raw) ?? .individualImages
        }
        set { defaults.set(newValue.rawValue, forKey: Self.formatKey) }
    }

    var applyWatermark: Bool {
        get { defaults.bool(forKey: Self.applyWatermarkKey) }
        set { defaults.set(newValue, forKey: Self.applyWatermarkKey) }
    }

    var applyCombineSettings: Bool {
        get { defaults.bool(forKey: Self.applyCombineKey) }
        set { defaults.set(newValue, forKey: Self.applyCombineKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Self.includeCombinedKey: true,
            Self.includeBeforeKey: false,
            Self.includeAfterKey: false,
            Self.formatKey: ExportFormat.individualImages.rawValue,
            Self.applyWatermarkKey: false,
            Self.applyCombineKey: true,
        ])
    }
}
