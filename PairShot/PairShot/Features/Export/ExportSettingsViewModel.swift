import Foundation
import Observation
import Photos

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
    var pendingRedirect: ExportSettingsRedirectTarget?

    private var zipSaveProgress: SnackbarProgressHandle?

    var hasAnyInclude: Bool {
        includeCombined || includeBefore || includeAfter
    }

    var canExecute: Bool {
        !isExporting && hasAnyInclude && !pairIds.isEmpty
    }

    private let pairRepo: PhotoPairRepository
    private let storage: PhotoStorageService
    private let exportPairs: ExportPairsUseCase
    private let photoLibrary: any PhotoLibraryExporting
    private let snackbarQueue: SnackbarQueue
    private let tempDirectoryProvider: @Sendable () -> URL
    private let eventsContinuation: AsyncStream<Event>.Continuation
    private let appSettings: AppSettings?
    private var preferences: ExportPreferences
    private let interstitialAdManager: InterstitialAdManager?
    private let adFreeStore: AdFreeStore?
    private let fullscreenAdCoordinator: FullscreenAdCoordinator?

    private var pendingZipURL: URL?

    init(
        pairIds: [UUID],
        albumId: UUID?,
        pairRepo: PhotoPairRepository,
        storage: PhotoStorageService,
        exportPairs: ExportPairsUseCase,
        photoLibrary: any PhotoLibraryExporting,
        snackbarQueue: SnackbarQueue,
        tempDirectoryProvider: @escaping @Sendable () -> URL = { FileManager.default.temporaryDirectory },
        preferences: ExportPreferences = ExportPreferences(),
        appSettings: AppSettings? = nil,
        interstitialAdManager: InterstitialAdManager? = nil,
        adFreeStore: AdFreeStore? = nil,
        fullscreenAdCoordinator: FullscreenAdCoordinator? = nil
    ) {
        self.pairIds = pairIds
        self.albumId = albumId
        self.pairRepo = pairRepo
        self.storage = storage
        self.exportPairs = exportPairs
        self.photoLibrary = photoLibrary
        self.snackbarQueue = snackbarQueue
        self.tempDirectoryProvider = tempDirectoryProvider
        self.preferences = preferences
        self.appSettings = appSettings
        self.interstitialAdManager = interstitialAdManager
        self.adFreeStore = adFreeStore
        self.fullscreenAdCoordinator = fullscreenAdCoordinator
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

    func requestWatermarkRedirect() {
        pendingRedirect = .watermarkSettings
    }

    func requestCombineRedirect() {
        pendingRedirect = .combineSettings
    }

    func consumeRedirect() -> ExportSettingsRedirectTarget? {
        let target = pendingRedirect
        pendingRedirect = nil
        return target
    }

    func share() async {
        guard canExecute else { return }
        await runWithInterstitial { [weak self] in
            await self?.performShare()
        }
    }

    func saveToDevice() async {
        guard canExecute else { return }
        await runWithInterstitial { [weak self] in
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
                        format: .zip,
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

    private func runWithInterstitial(_ work: @escaping @MainActor () async -> Void) async {
        guard
            let interstitialAdManager,
            let adFreeStore,
            let fullscreenAdCoordinator
        else {
            await work()
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task { @MainActor in
                await interstitialAdManager.showIfAvailable(
                    from: BannerAdView.resolveTopPresentedViewController(),
                    adFreeStore: adFreeStore,
                    coordinator: fullscreenAdCoordinator
                ) {
                    Task { @MainActor in
                        await work()
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func saveImagesToPhotoLibrary(progress: SnackbarProgressHandle) async {
        let status = await photoLibrary.authorize()
        guard status == .authorized || status == .limited else {
            snackbarQueue.cancelProgress(progress)
            errorMessage = "snackbar_error_save_failed"
            return
        }
        var saved = 0
        var processed = 0
        do {
            let pairs = try await loadPairs()
            let mode = makeMode()
            let entries = pairs.flatMap { ExportSelection.relativePaths(for: $0, mode: mode) }
            let total = max(1, entries.count)
            let watermark = activeWatermarkForIndividuals()
            for entry in entries {
                guard
                    let payload = WatermarkedSourceProvider.resolveDataAndExtension(
                        for: entry,
                        storage: storage,
                        watermark: watermark
                    )
                else {
                    processed += 1
                    snackbarQueue.updateProgress(progress, value: Double(processed) / Double(total))
                    continue
                }
                try await photoLibrary.saveImageData(payload.data, type: .photo)
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
                format: .zip,
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
        let mode = makeMode()
        let entries = pairs.flatMap { ExportSelection.relativePaths(for: $0, mode: mode) }
        return WatermarkedSourceProvider.resolveURLs(
            entries: entries,
            storage: storage,
            watermark: activeWatermarkForIndividuals(),
            tempDirectory: tempDirectoryProvider()
        )
    }

    private func activeWatermarkForIndividuals() -> WatermarkSettings? {
        guard
            let appSettings,
            appSettings.watermarkEnabled,
            applyWatermark
        else { return nil }
        return appSettings.watermarkSettings
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

    private func makeSelection() -> ExportContents {
        ExportContentsMapping.fromIncludes(
            combined: includeCombined,
            before: includeBefore,
            after: includeAfter
        )
    }

    private func makeMode() -> ExportMode {
        ExportContentsMapping.toMode(makeSelection())
    }

    deinit {}
}

extension ExportContentsMapping {
    static func fromIncludes(combined: Bool, before: Bool, after: Bool) -> ExportContents {
        let count = [combined, before, after].count(where: { $0 })
        if count >= 2 { return .all }
        if combined { return .combinedOnly }
        if before { return .beforeOnly }
        if after { return .afterOnly }
        return .all
    }
}

nonisolated final class ExportPreferences: @unchecked Sendable {
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
        // swiftlint:disable trailing_comma
        defaults.register(defaults: [
            Self.includeCombinedKey: true,
            Self.includeBeforeKey: false,
            Self.includeAfterKey: false,
            Self.formatKey: ExportFormat.individualImages.rawValue,
            Self.applyWatermarkKey: false,
            Self.applyCombineKey: true,
        ])
        // swiftlint:enable trailing_comma
    }

    deinit {}
}
