import Foundation
import Photos
import UIKit

enum SaveToDeviceOutcome {
    case completed
    case zipPendingExport(url: URL, progress: SnackbarProgressHandle)
}

final class ImmediateExportService {
    let photoLibrary: PhotoLibraryService
    let exportPairs: ExportPairsUseCase
    let photoLibraryExporter: PhotoLibraryExport
    let snackbarQueue: SnackbarQueue
    let preferences: ExportPreferences
    let tempDirectoryProvider: @Sendable () -> URL
    let appSettings: AppSettings
    let pairRepo: PhotoPairRepository
    let membership: Membership?

    private var hasAnyInclude: Bool {
        preferences.includeCombined || preferences.includeBefore || preferences.includeAfter
    }

    init(
        photoLibrary: PhotoLibraryService,
        exportPairs: ExportPairsUseCase,
        photoLibraryExporter: PhotoLibraryExport,
        snackbarQueue: SnackbarQueue,
        appSettings: AppSettings,
        pairRepo: PhotoPairRepository,
        membership: Membership? = nil,
        preferences: ExportPreferences = ExportPreferences(),
        tempDirectoryProvider: @escaping @Sendable () -> URL = { FileManager.default.temporaryDirectory },
    ) {
        self.photoLibrary = photoLibrary
        self.exportPairs = exportPairs
        self.photoLibraryExporter = photoLibraryExporter
        self.snackbarQueue = snackbarQueue
        self.appSettings = appSettings
        self.pairRepo = pairRepo
        self.membership = membership
        self.preferences = preferences
        self.tempDirectoryProvider = tempDirectoryProvider
    }

    func makeShareItems(for pairs: [PhotoPair]) async throws -> ExportShareItems {
        let selection = currentSelection()
        guard hasAnyInclude else {
            return ExportShareItems(values: [])
        }
        let token = "share-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            "snackbar_progress_share",
            token: token,
            initialValue: 0,
        )
        do {
            snackbarQueue.updateProgress(handle, value: 0.5)
            switch preferences.format {
                case .zip:
                    let url = try await exportPairs(
                        ids: pairs.map(\.id),
                        selection: selection,
                        renderOptions: currentRenderOptions(),
                        tempDirectory: tempDirectoryProvider(),
                    )
                    snackbarQueue.completeProgress(handle, finalMessage: nil)
                    return ExportShareItems(values: [url])

                case .individualImages:
                    let urls = await collectIndividualSourceURLs(for: pairs, selection: selection)
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
                debounceKey: "save-nothing",
            )
            return .completed
        }
        let token = "save-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            "snackbar_progress_save_to_device",
            token: token,
            initialValue: 0,
        )
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
                finalVariant: .success,
            )
        } else {
            snackbarQueue.cancelProgress(progress)
        }
        try? FileManager.default.removeItem(at: url)
    }

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
            debounceKey: "share-failure",
        )
    }

    func currentSelection() -> ExportContents {
        ExportContents(
            includeCombined: preferences.includeCombined,
            includeBefore: preferences.includeBefore,
            includeAfter: preferences.includeAfter,
        )
    }

    @MainActor
    func currentRenderOptions() -> ExportRenderOptions {
        ExportRenderOptions(
            applyCombineSettings: preferences.applyCombineSettings,
            isPro: membership?.proIsActive ?? false,
        )
    }

    private func collectIndividualSourceURLs(
        for pairs: [PhotoPair],
        selection: ExportContents,
    ) async -> [URL] {
        let renderOptions = currentRenderOptions()
        let tempDir = tempDirectoryProvider()
        var urls: [URL] = []
        let now = Date()
        let ext = appSettings.exportQuality.fileExtension
        for (offset, pair) in pairs.enumerated() {
            let entries = ExportSelection.relativePaths(
                for: pair,
                selection: selection,
                sequenceNumber: offset + 1,
                prefix: appSettings.fileNamePrefix,
                fileExtension: ext,
            )
            for entry in entries {
                guard
                    let rendered = await ExportEntryRenderer.render(
                        entry: entry,
                        pair: pair,
                        photoLibrary: photoLibrary,
                        appSettings: appSettings,
                        renderOptions: renderOptions,
                        now: now,
                    )
                else { continue }
                let fileName = ExportTempFileWriter.sanitizedName(from: entry.relativeName)
                if let url = ExportTempFileWriter.write(
                    data: rendered.data,
                    fileName: fileName,
                    tempDirectory: tempDir,
                ) {
                    urls.append(url)
                }
            }
        }
        return urls
    }

    private func prepareZipForExport(
        pairs: [PhotoPair],
        progress: SnackbarProgressHandle,
    ) async -> SaveToDeviceOutcome {
        do {
            let url = try await exportPairs(
                ids: pairs.map(\.id),
                selection: currentSelection(),
                renderOptions: currentRenderOptions(),
                tempDirectory: tempDirectoryProvider(),
            )
            snackbarQueue.updateProgress(progress, value: 1.0)
            return .zipPendingExport(url: url, progress: progress)
        } catch {
            snackbarQueue.cancelProgress(progress)
            snackbarQueue.enqueue(
                "snackbar_error_save_failed",
                variant: .error,
                debounceKey: "save-failure",
            )
            return .completed
        }
    }
}
