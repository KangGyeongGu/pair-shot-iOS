import Foundation
import Photos

enum SaveToDeviceOutcome {
    case completed
    case zipPendingExport(url: URL, progress: SnackbarProgressHandle)
}

@MainActor
final class ImmediateExportService {
    private let storage: PhotoStorageService
    private let exportPairs: ExportPairsUseCase
    private let photoLibrary: any PhotoLibraryExporting
    private let snackbarQueue: SnackbarQueue
    private let preferences: ExportPreferences
    private let tempDirectoryProvider: @Sendable () -> URL
    private let compositor: (any CompositorService)?
    private let appSettings: AppSettings?

    private var hasAnyInclude: Bool {
        preferences.includeCombined || preferences.includeBefore || preferences.includeAfter
    }

    init(
        storage: PhotoStorageService,
        exportPairs: ExportPairsUseCase,
        photoLibrary: any PhotoLibraryExporting,
        snackbarQueue: SnackbarQueue,
        preferences: ExportPreferences = ExportPreferences(),
        tempDirectoryProvider: @escaping @Sendable () -> URL = { FileManager.default.temporaryDirectory },
        compositor: (any CompositorService)? = nil,
        appSettings: AppSettings? = nil
    ) {
        self.storage = storage
        self.exportPairs = exportPairs
        self.photoLibrary = photoLibrary
        self.snackbarQueue = snackbarQueue
        self.preferences = preferences
        self.tempDirectoryProvider = tempDirectoryProvider
        self.compositor = compositor
        self.appSettings = appSettings
    }

    // swiftlint:disable switch_case_alignment
    func makeShareItems(for pairs: [PhotoPair]) async throws -> ExportShareItems {
        let selection = currentSelection()
        guard hasAnyInclude else {
            return ExportShareItems(values: [])
        }
        let token = "share-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            "snackbar_progress_share",
            token: token,
            initialValue: 0
        )
        do {
            await prepareCompositesIfNeeded(for: pairs, progress: handle)
            snackbarQueue.updateProgress(handle, value: 0.5)
            switch preferences.format {
                case .zip:
                    let url = try await exportPairs(
                        ids: pairs.map(\.id),
                        selection: selection,
                        format: .zip,
                        tempDirectory: tempDirectoryProvider()
                    )
                    snackbarQueue.completeProgress(handle, finalMessage: nil)
                    return ExportShareItems(values: [url])

                case .individualImages:
                    let urls = collectIndividualSourceURLs(
                        for: pairs,
                        mode: ExportContentsMapping.toMode(selection)
                    )
                    snackbarQueue.completeProgress(handle, finalMessage: nil)
                    return ExportShareItems(values: urls)
            }
        } catch {
            snackbarQueue.cancelProgress(handle)
            throw error
        }
    }

    func saveToDevice(pairs: [PhotoPair]) async -> SaveToDeviceOutcome {
        guard hasAnyInclude else {
            snackbarQueue.enqueue(
                "snackbar_warning_nothing_to_save",
                variant: .warning,
                debounceKey: "save-nothing"
            )
            return .completed
        }
        let token = "save-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            "snackbar_progress_save_to_device",
            token: token,
            initialValue: 0
        )
        await prepareCompositesIfNeeded(for: pairs, progress: handle)
        switch preferences.format {
            case .individualImages:
                await saveImagesToPhotoLibrary(pairs: pairs, progress: handle)
                return .completed

            case .zip:
                return await prepareZipForExport(pairs: pairs, progress: handle)
        }
    }

    func finishZipExport(url: URL, progress: SnackbarProgressHandle, saved: Bool) {
        if saved {
            snackbarQueue.completeProgress(
                progress,
                finalMessage: "snackbar_success_saved_zip",
                finalVariant: .success
            )
        } else {
            snackbarQueue.cancelProgress(progress)
        }
        try? FileManager.default.removeItem(at: url)
    }

    // swiftlint:enable switch_case_alignment

    func cleanup(items: ExportShareItems) {
        for value in items.values {
            guard let url = value as? URL else { continue }
            if url.pathExtension.lowercased() == "zip" {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    func notifyShareFailure() {
        snackbarQueue.enqueue(
            "snackbar_error_share_failed",
            variant: .error,
            debounceKey: "share-failure"
        )
    }

    private func prepareCompositesIfNeeded(for pairs: [PhotoPair], progress: SnackbarProgressHandle? = nil) async {
        guard preferences.includeCombined,
              preferences.applyCombineSettings,
              let compositor,
              let appSettings
        else { return }
        let layout = appSettings.combineSettings.direction == .vertical ? CompositeLayout.vertical : CompositeLayout
            .horizontal
        let options = CompositeOptions(
            layout: layout,
            jpegQuality: CGFloat(appSettings.jpegQuality),
            watermarkEnabled: appSettings.watermarkEnabled && preferences.applyWatermark,
            watermark: appSettings.watermarkEnabled && preferences.applyWatermark ? appSettings.watermarkSettings : nil,
            combineSettings: appSettings.combineSettings
        )
        let prefix = FileNamePrefixValidator.sanitize(appSettings.fileNamePrefix)
        let total = max(1, pairs.count(where: { $0.afterFileName != nil }))
        var done = 0
        for pair in pairs where pair.afterFileName != nil {
            do {
                _ = try await compositor.makeComposite(
                    for: pair,
                    options: options,
                    fileNamePrefix: prefix,
                    now: .now
                )
                done += 1
                if let progress {
                    snackbarQueue.updateProgress(progress, value: 0.5 * Double(done) / Double(total))
                }
            } catch {
                if let progress {
                    snackbarQueue.cancelProgress(progress)
                }
                snackbarQueue.enqueue(
                    "snackbar_error_composite_failed",
                    variant: .error,
                    debounceKey: "composite-error"
                )
                return
            }
        }
    }

    private func currentSelection() -> ExportContents {
        ExportContentsMapping.fromIncludes(
            combined: preferences.includeCombined,
            before: preferences.includeBefore,
            after: preferences.includeAfter
        )
    }

    private func collectIndividualSourceURLs(for pairs: [PhotoPair], mode: ExportMode) -> [URL] {
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
            preferences.applyWatermark
        else { return nil }
        return appSettings.watermarkSettings
    }

    private func saveImagesToPhotoLibrary(pairs: [PhotoPair], progress: SnackbarProgressHandle) async {
        let status = await photoLibrary.authorize()
        guard status == .authorized || status == .limited else {
            snackbarQueue.cancelProgress(progress)
            snackbarQueue.enqueue(
                "snackbar_error_save_failed",
                variant: .error,
                debounceKey: "save-failure"
            )
            return
        }
        let mode = ExportContentsMapping.toMode(currentSelection())
        let entries = pairs.flatMap { ExportSelection.relativePaths(for: $0, mode: mode) }
        let total = max(1, entries.count)
        let watermark = activeWatermarkForIndividuals()
        var saved = 0
        var processed = 0
        for entry in entries {
            guard
                let payload = WatermarkedSourceProvider.resolveDataAndExtension(
                    for: entry,
                    storage: storage,
                    watermark: watermark
                )
            else {
                processed += 1
                snackbarQueue.updateProgress(progress, value: 0.5 + 0.5 * Double(processed) / Double(total))
                continue
            }
            do {
                try await photoLibrary.saveImageData(payload.data, type: .photo)
                saved += 1
                processed += 1
                snackbarQueue.updateProgress(progress, value: 0.5 + 0.5 * Double(processed) / Double(total))
            } catch {
                snackbarQueue.cancelProgress(progress)
                snackbarQueue.enqueue(
                    "snackbar_error_save_failed",
                    variant: .error,
                    debounceKey: "save-failure"
                )
                return
            }
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
    }

    private func prepareZipForExport(
        pairs: [PhotoPair],
        progress: SnackbarProgressHandle
    ) async -> SaveToDeviceOutcome {
        do {
            let url = try await exportPairs(
                ids: pairs.map(\.id),
                selection: currentSelection(),
                format: .zip,
                tempDirectory: tempDirectoryProvider()
            )
            snackbarQueue.updateProgress(progress, value: 1.0)
            return .zipPendingExport(url: url, progress: progress)
        } catch {
            snackbarQueue.cancelProgress(progress)
            snackbarQueue.enqueue(
                "snackbar_error_save_failed",
                variant: .error,
                debounceKey: "save-failure"
            )
            return .completed
        }
    }

    deinit {}
}
