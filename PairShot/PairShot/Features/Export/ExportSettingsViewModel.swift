import Foundation
import Observation
import Photos
import UIKit

struct ExportShareItems: Identifiable {
    let id = UUID()
    let values: [Any]
}

@MainActor
@Observable
final class ExportSettingsViewModel {
    typealias GateResult = RewardedGateResult

    enum Event {
        case completed
        case dismiss
    }

    let pairIds: [UUID]
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
        get { appSettings.watermarkEnabled }
        set { appSettings.watermarkEnabled = newValue }
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
    var showPaywall: Bool = false
    var lastGateFailureReason: String?

    var zipSaveProgress: SnackbarProgressHandle?

    private var currentExportTask: Task<Void, Never>?

    var hasAnyInclude: Bool {
        includeCombined || includeBefore || includeAfter
    }

    var canExecute: Bool {
        !isExporting && hasAnyInclude && !pairIds.isEmpty
    }

    var watermarkSettingsBlank: Bool {
        appSettings.watermarkSettings.isBlank
    }

    var isProUser: Bool {
        membership?.proIsActive ?? false
    }

    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService
    let exportPairs: ExportPairsUseCase
    let photoLibraryExporter: PhotoLibraryExport
    let snackbarQueue: SnackbarQueue
    let tempDirectoryProvider: @Sendable () -> URL
    let eventsContinuation: AsyncStream<Event>.Continuation
    let appSettings: AppSettings
    var preferences: ExportPreferences
    let interstitialAdManager: InterstitialAdManager?
    let membership: Membership?
    let fullscreenAdCoordinator: FullscreenAdCoordinator?

    var pendingZipURL: URL?

    init(
        pairIds: [UUID],
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        exportPairs: ExportPairsUseCase,
        photoLibraryExporter: PhotoLibraryExport,
        snackbarQueue: SnackbarQueue,
        appSettings: AppSettings,
        tempDirectoryProvider: @escaping @Sendable () -> URL = { FileManager.default.temporaryDirectory },
        preferences: ExportPreferences = ExportPreferences(),
        interstitialAdManager: InterstitialAdManager? = nil,
        membership: Membership? = nil,
        fullscreenAdCoordinator: FullscreenAdCoordinator? = nil,
    ) {
        self.pairIds = pairIds
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.exportPairs = exportPairs
        self.photoLibraryExporter = photoLibraryExporter
        self.snackbarQueue = snackbarQueue
        self.tempDirectoryProvider = tempDirectoryProvider
        self.preferences = preferences
        self.appSettings = appSettings
        self.interstitialAdManager = interstitialAdManager
        self.membership = membership
        self.fullscreenAdCoordinator = fullscreenAdCoordinator
        includeCombined = preferences.includeCombined
        includeBefore = preferences.includeBefore
        includeAfter = preferences.includeAfter
        format = preferences.format
        applyCombineSettings = preferences.applyCombineSettings
        let stream = AsyncStream<Event>.makeStream()
        events = stream.stream
        eventsContinuation = stream.continuation
    }

    func cleanupPendingZip() {
        guard let url = pendingZipURL else { return }
        pendingZipURL = nil
        try? FileManager.default.removeItem(at: url)
    }

    func cancelPendingExport() {
        currentExportTask?.cancel()
        currentExportTask = nil
        if let progress = zipSaveProgress {
            zipSaveProgress = nil
            snackbarQueue.cancelProgress(progress)
        }
    }

    func clearShareItems() {
        shareItems = nil
        cleanupPendingZip()
        eventsContinuation.yield(.completed)
        eventsContinuation.yield(.dismiss)
    }

    func share() async {
        guard canExecute else { return }
        guard ensureExportEligibility() else { return }
        currentExportTask?.cancel()
        let task = Task { @MainActor [weak self] in
            await InterstitialAdManager.runGated(
                manager: self?.interstitialAdManager,
                promotionStore: self?.membership?.promotionStore,
                subscriptionStore: self?.membership?.subscriptionStore,
                coordinator: self?.fullscreenAdCoordinator,
            ) {
                await self?.performShare()
            }
        }
        currentExportTask = task
        await task.value
        currentExportTask = nil
    }

    func saveToDevice() async {
        guard canExecute else { return }
        guard ensureExportEligibility() else { return }
        currentExportTask?.cancel()
        let task = Task { @MainActor [weak self] in
            await InterstitialAdManager.runGated(
                manager: self?.interstitialAdManager,
                promotionStore: self?.membership?.promotionStore,
                subscriptionStore: self?.membership?.subscriptionStore,
                coordinator: self?.fullscreenAdCoordinator,
            ) {
                await self?.performSaveToDevice()
            }
        }
        currentExportTask = task
        await task.value
        currentExportTask = nil
    }

    func handleZipExportCompleted(_ saved: Bool) {
        zipExportItem = nil
        if let progress = zipSaveProgress {
            zipSaveProgress = nil
            if saved {
                snackbarQueue.completeProgress(
                    progress,
                    finalMessage: "snackbar_success_saved_zip",
                    finalVariant: .success,
                )
            } else {
                snackbarQueue.cancelProgress(progress)
            }
        }
        cleanupPendingZip()
        if saved {
            eventsContinuation.yield(.completed)
            eventsContinuation.yield(.dismiss)
        }
    }

    func makeSelection() -> ExportContents {
        ExportContents(
            includeCombined: includeCombined,
            includeBefore: includeBefore,
            includeAfter: includeAfter,
        )
    }

    func makeRenderOptions() -> ExportRenderOptions {
        ExportRenderOptions(
            applyCombineSettings: applyCombineSettings,
            isPro: membership?.proIsActive ?? false,
        )
    }

    func ensureExportEligibility() -> Bool {
        if format == .zip, !isProUser {
            snackbarQueue.enqueue(
                "settings_promotion_guide_pro_feature",
                variant: .info,
                debounceKey: "pro_gate_pro_feature",
            )
            showPaywall = true
            return false
        }
        if applyWatermark, watermarkSettingsBlank {
            snackbarQueue.enqueue(
                "snackbar_warning_watermark_setup_required",
                variant: .warning,
                debounceKey: "watermark-setup-required",
            )
            return false
        }
        return true
    }

    func selectFormat(_ newFormat: ExportFormat) {
        if newFormat == .zip, !isProUser {
            snackbarQueue.enqueue(
                "settings_promotion_guide_pro_feature",
                variant: .info,
                debounceKey: "pro_gate_pro_feature",
            )
            showPaywall = true
            return
        }
        format = newFormat
    }
}
