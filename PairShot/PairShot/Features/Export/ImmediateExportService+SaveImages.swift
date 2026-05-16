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
        let now = Date()
        let jobs = ExportJobBuilder.makeJobs(
            pairs: pairs,
            selection: selection,
            appSettings: appSettings,
            renderOptions: renderOptions,
            now: now,
        )
        let saved = await processJobs(
            jobs,
            renderOptions: renderOptions,
            progress: progress,
        )
        finalizeProgress(progress, savedCount: saved)
    }

    func processJobs(
        _ jobs: [ExportJob],
        renderOptions: ExportRenderOptions,
        progress: SnackbarProgressHandle,
    ) async -> Int {
        let total = max(1, jobs.count)
        let snackbar = snackbarQueue
        let progressToken = progress.token
        let counter = ExportProgressCounter(total: jobs.count) { fraction in
            Task { @MainActor in
                snackbar.updateProgress(SnackbarProgressHandle(token: progressToken), value: fraction)
            }
        }
        let payloads: [RenderedExportPayload]
        do {
            payloads = try await ExportEntryBatchRenderer.renderAll(
                jobs: jobs,
                photoLibrary: photoLibrary,
                counter: counter,
            )
        } catch is CancellationError {
            return 0
        } catch {
            enqueueSaveFailure(progress: progress)
            return 0
        }
        var saved = 0
        for payload in payloads {
            do {
                let identifier = try await photoLibraryExporter.saveImageData(
                    payload.data,
                    type: .photo,
                    utType: payload.utType,
                )
                await recordExportHistory(
                    identifier: identifier,
                    pairId: payload.pairId,
                    entry: payload.entry,
                    renderOptions: renderOptions,
                )
                saved += 1
            } catch {
                enqueueSaveFailure(progress: progress)
                return saved
            }
        }
        snackbarQueue.updateProgress(progress, value: Double(saved) / Double(total))
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
        pairId: UUID,
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
                pairId: pairId,
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
