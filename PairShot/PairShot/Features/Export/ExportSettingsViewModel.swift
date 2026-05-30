import Foundation
import Observation

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

    static let presetNameMaxLength = 12

    let pairIds: [UUID]
    let events: AsyncStream<Event>

    var includeCombined: Bool {
        get { preferences.includeCombined }
        set {
            preferences.includeCombined = newValue
            exportPresetStore?.syncFromGlobal()
        }
    }

    var includeBefore: Bool {
        get { preferences.includeBefore }
        set {
            preferences.includeBefore = newValue
            exportPresetStore?.syncFromGlobal()
        }
    }

    var includeAfter: Bool {
        get { preferences.includeAfter }
        set {
            preferences.includeAfter = newValue
            exportPresetStore?.syncFromGlobal()
        }
    }

    var format: ExportFormat {
        get { preferences.format }
        set {
            preferences.format = newValue
            exportPresetStore?.syncFromGlobal()
        }
    }

    var applyWatermark: Bool {
        get { appSettings.watermarkEnabled }
        set {
            appSettings.watermarkEnabled = newValue
            exportPresetStore?.syncFromGlobal()
        }
    }

    var applyCombineSettings: Bool {
        get { preferences.applyCombineSettings }
        set {
            preferences.applyCombineSettings = newValue
            exportPresetStore?.syncFromGlobal()
        }
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
    let logoStore: WatermarkLogoStore

    var pendingZipURL: URL?

    let exportPresetStore: ExportPresetStore?

    var pendingPresetSaveSlotIndex: Int?
    var presetSaveNameInput: String = "" {
        didSet {
            if presetSaveNameInput.count > Self.presetNameMaxLength {
                presetSaveNameInput = String(presetSaveNameInput.prefix(Self.presetNameMaxLength))
            }
        }
    }

    var pendingPresetRenameSlotIndex: Int?
    var presetRenameNameInput: String = "" {
        didSet {
            if presetRenameNameInput.count > Self.presetNameMaxLength {
                presetRenameNameInput = String(presetRenameNameInput.prefix(Self.presetNameMaxLength))
            }
        }
    }

    var pendingPresetActionSheetSlotIndex: Int?
    var pendingPresetDeleteSlotIndex: Int?

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
        exportPresetStore: ExportPresetStore? = nil,
        logoStore: WatermarkLogoStore = WatermarkLogoStore(),
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
        self.exportPresetStore = exportPresetStore
        self.logoStore = logoStore
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
                    finalReason: .savedZip,
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
                .proFeatureGate,
                debounceKey: "pro_gate_pro_feature",
            )
            showPaywall = true
            return false
        }
        if applyWatermark, watermarkSettingsBlank {
            snackbarQueue.enqueue(
                .watermarkSetupRequired,
                debounceKey: "watermark-setup-required",
            )
            return false
        }
        return true
    }

    func selectFormat(_ newFormat: ExportFormat) {
        if newFormat == .zip, !isProUser {
            snackbarQueue.enqueue(
                .proFeatureGate,
                debounceKey: "pro_gate_pro_feature",
            )
            showPaywall = true
            return
        }
        format = newFormat
    }
}
