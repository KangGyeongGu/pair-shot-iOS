import Foundation
import OSLog
import Photos

extension ImmediateExportService {
    func saveImagesToPhotoLibrary(pairs: [PhotoPair], progress: SnackbarProgressHandle) async {
        let status = await photoLibraryExporter.authorize()
        guard status == .authorized || status == .limited else {
            enqueueSaveFailure(progress: progress)
            return
        }
        let selection = currentSelection()
        let renderOptions = currentRenderOptions()
        let allEntries = collectExportEntries(pairs: pairs, selection: selection)
        let saved = await processEntries(
            allEntries,
            renderOptions: renderOptions,
            progress: progress,
        )
        finalizeProgress(progress, savedCount: saved)
    }

    func collectExportEntries(
        pairs: [PhotoPair],
        selection: ExportContents,
    ) -> [(pair: PhotoPair, entry: ExportSelection.Entry)] {
        pairs.enumerated().flatMap { offset, pair in
            ExportSelection.relativePaths(
                for: pair,
                selection: selection,
                sequenceNumber: offset + 1,
                prefix: appSettings.fileNamePrefix,
            )
            .map { (pair: pair, entry: $0) }
        }
    }

    func processEntries(
        _ allEntries: [(pair: PhotoPair, entry: ExportSelection.Entry)],
        renderOptions: ExportRenderOptions,
        progress: SnackbarProgressHandle,
    ) async -> Int {
        let total = max(1, allEntries.count)
        let now = Date()
        var saved = 0
        var processed = 0
        for item in allEntries {
            guard
                let data = await ExportEntryRenderer.render(
                    entry: item.entry,
                    pair: item.pair,
                    photoLibrary: photoLibrary,
                    appSettings: appSettings,
                    renderOptions: renderOptions,
                    now: now,
                )
            else {
                processed += 1
                snackbarQueue.updateProgress(progress, value: Double(processed) / Double(total))
                continue
            }
            do {
                let identifier = try await photoLibraryExporter.saveImageData(data, type: .photo)
                await recordExportHistory(
                    identifier: identifier,
                    pair: item.pair,
                    entry: item.entry,
                    renderOptions: renderOptions,
                )
                saved += 1
                processed += 1
                snackbarQueue.updateProgress(progress, value: Double(processed) / Double(total))
            } catch {
                enqueueSaveFailure(progress: progress)
                return saved
            }
        }
        return saved
    }

    func finalizeProgress(_ progress: SnackbarProgressHandle, savedCount: Int) {
        if savedCount == 0 {
            snackbarQueue.completeProgress(
                progress,
                finalMessage: "snackbar_warning_nothing_to_save",
                finalVariant: .warning,
            )
        } else {
            snackbarQueue.completeProgress(
                progress,
                finalMessage: "snackbar_success_saved_to_device",
                finalVariant: .success,
            )
        }
    }

    func enqueueSaveFailure(progress: SnackbarProgressHandle) {
        snackbarQueue.cancelProgress(progress)
        snackbarQueue.enqueue(
            "snackbar_error_save_failed",
            variant: .error,
            debounceKey: "save-failure",
        )
    }

    func recordExportHistory(
        identifier: String,
        pair: PhotoPair,
        entry: ExportSelection.Entry,
        renderOptions: ExportRenderOptions,
    ) async {
        guard
            let kind = await MainActor.run(body: {
                ExportHistoryKindResolver.resolve(
                    entryKind: entry.kind,
                    renderOptions: renderOptions,
                    appSettings: appSettings,
                )
            })
        else { return }
        do {
            try await pairRepo.recordExportHistory(
                pairId: pair.id,
                kind: kind,
                photoLocalIdentifier: identifier,
            )
        } catch {
            AppLogger.storage.error(
                "ExportHistory persist failed: \(error.localizedDescription, privacy: .public)",
            )
        }
    }
}
