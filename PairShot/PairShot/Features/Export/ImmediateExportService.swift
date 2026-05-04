import Foundation
import OSLog
import Photos
import SwiftData
import UIKit

enum SaveToDeviceOutcome {
    case completed
    case zipPendingExport(url: URL, progress: SnackbarProgressHandle)
}

@MainActor
final class ImmediateExportService {
    private let photoLibrary: PhotoLibraryService
    private let exportPairs: ExportPairsUseCase
    private let photoLibraryExporter: PhotoLibraryExport
    private let snackbarQueue: SnackbarQueue
    private let preferences: ExportPreferences
    private let tempDirectoryProvider: @Sendable () -> URL
    private let appSettings: AppSettings
    private let modelContainer: ModelContainer?

    private var hasAnyInclude: Bool {
        preferences.includeCombined || preferences.includeBefore || preferences.includeAfter
    }

    init(
        photoLibrary: PhotoLibraryService,
        exportPairs: ExportPairsUseCase,
        photoLibraryExporter: PhotoLibraryExport,
        snackbarQueue: SnackbarQueue,
        appSettings: AppSettings,
        modelContainer: ModelContainer? = nil,
        preferences: ExportPreferences = ExportPreferences(),
        tempDirectoryProvider: @escaping @Sendable () -> URL = { FileManager.default.temporaryDirectory }
    ) {
        self.photoLibrary = photoLibrary
        self.exportPairs = exportPairs
        self.photoLibraryExporter = photoLibraryExporter
        self.snackbarQueue = snackbarQueue
        self.appSettings = appSettings
        self.modelContainer = modelContainer
        self.preferences = preferences
        self.tempDirectoryProvider = tempDirectoryProvider
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
            snackbarQueue.updateProgress(handle, value: 0.5)
            switch preferences.format {
                case .zip:
                    let url = try await exportPairs(
                        ids: pairs.map(\.id),
                        selection: selection,
                        renderOptions: currentRenderOptions(),
                        tempDirectory: tempDirectoryProvider()
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

    private func currentSelection() -> ExportContents {
        ExportContents(
            includeCombined: preferences.includeCombined,
            includeBefore: preferences.includeBefore,
            includeAfter: preferences.includeAfter
        )
    }

    private func currentRenderOptions() -> ExportRenderOptions {
        ExportRenderOptions(
            applyCombineSettings: preferences.applyCombineSettings,
            applyWatermark: preferences.applyWatermark
        )
    }

    private func collectIndividualSourceURLs(
        for pairs: [PhotoPair],
        selection: ExportContents
    ) async -> [URL] {
        let renderOptions = currentRenderOptions()
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

    private func saveImagesToPhotoLibrary(pairs: [PhotoPair], progress: SnackbarProgressHandle) async {
        let status = await photoLibraryExporter.authorize()
        guard status == .authorized || status == .limited else {
            snackbarQueue.cancelProgress(progress)
            snackbarQueue.enqueue(
                "snackbar_error_save_failed",
                variant: .error,
                debounceKey: "save-failure"
            )
            return
        }
        let selection = currentSelection()
        let renderOptions = currentRenderOptions()
        let now = Date()
        let allEntries: [(pair: PhotoPair, entry: ExportSelection.Entry)] = pairs.flatMap { pair in
            ExportSelection.relativePaths(for: pair, selection: selection, now: now)
                .map { (pair: pair, entry: $0) }
        }
        let total = max(1, allEntries.count)
        var saved = 0
        var processed = 0
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
            do {
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
        let record = ExportHistoryEntity(
            kind: kind,
            photoLocalIdentifier: identifier,
            pair: pair
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

    private func prepareZipForExport(
        pairs: [PhotoPair],
        progress: SnackbarProgressHandle
    ) async -> SaveToDeviceOutcome {
        do {
            let url = try await exportPairs(
                ids: pairs.map(\.id),
                selection: currentSelection(),
                renderOptions: currentRenderOptions(),
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
}
