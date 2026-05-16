import Foundation
import Photos

extension ExportSettingsViewModel {
    func performShare() async {
        isExporting = true
        defer { isExporting = false }
        let token = "export-share-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            "snackbar_progress_share",
            token: token,
            initialValue: 0,
        )
        do {
            switch format {
                case .zip:
                    snackbarQueue.updateProgress(handle, value: 0.3)
                    let url = try await exportPairs(
                        ids: pairIds,
                        selection: makeSelection(),
                        renderOptions: makeRenderOptions(),
                        tempDirectory: tempDirectoryProvider(),
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

    func performSaveToDevice() async {
        isExporting = true
        defer { isExporting = false }
        let token = "export-save-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            "snackbar_progress_save_to_device",
            token: token,
            initialValue: 0,
        )
        switch format {
            case .individualImages:
                await saveImagesToPhotoLibrary(progress: handle)

            case .zip:
                await saveZipToTemporaryAndNotify(progress: handle)
        }
    }

    func saveImagesToPhotoLibrary(progress: SnackbarProgressHandle) async {
        let status = await photoLibraryExporter.authorize()
        guard status == .authorized || status == .limited else {
            snackbarQueue.cancelProgress(progress)
            errorMessage = "snackbar_error_save_failed"
            return
        }
        let now = Date()
        let renderOptions = makeRenderOptions()
        let selection = makeSelection()
        let saved: Int
        do {
            let pairs = try await loadPairs()
            let jobs = ExportJobBuilder.makeJobs(
                pairs: pairs,
                selection: selection,
                appSettings: appSettings,
                renderOptions: renderOptions,
                now: now,
            )
            saved = await processJobs(
                jobs,
                progress: progress,
                renderOptions: renderOptions,
            )
        } catch {
            snackbarQueue.cancelProgress(progress)
            errorMessage = "snackbar_error_save_failed"
            return
        }
        finalizeSaveProgress(progress, savedCount: saved)
        eventsContinuation.yield(.completed)
        eventsContinuation.yield(.dismiss)
    }

    func processJobs(
        _ jobs: [ExportJob],
        progress: SnackbarProgressHandle,
        renderOptions: ExportRenderOptions,
    ) async -> Int {
        let total = max(1, jobs.count)
        let snackbar = snackbarQueue
        let progressToken = progress.token
        let counter = ExportProgressCounter(total: jobs.count) { fraction, done, total in
            Task { @MainActor in
                snackbar.updateProgress(
                    SnackbarProgressHandle(token: progressToken),
                    value: fraction,
                    processed: done,
                    total: total,
                )
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
                return saved
            }
        }
        snackbarQueue.updateProgress(
            progress,
            value: Double(saved) / Double(total),
            processed: saved,
            total: total,
        )
        return saved
    }

    func finalizeSaveProgress(_ progress: SnackbarProgressHandle, savedCount: Int) {
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

    func saveZipToTemporaryAndNotify(progress: SnackbarProgressHandle) async {
        do {
            snackbarQueue.updateProgress(progress, value: 0.3)
            let url = try await exportPairs(
                ids: pairIds,
                selection: makeSelection(),
                renderOptions: makeRenderOptions(),
                tempDirectory: tempDirectoryProvider(),
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

    func collectIndividualSourceURLs() async throws -> [URL] {
        let pairs = try await loadPairs()
        let selection = makeSelection()
        let renderOptions = makeRenderOptions()
        let tempDir = tempDirectoryProvider()
        let now = Date()
        let jobs = ExportJobBuilder.makeJobs(
            pairs: pairs,
            selection: selection,
            appSettings: appSettings,
            renderOptions: renderOptions,
            now: now,
        )
        let payloads: [RenderedExportPayload]
        do {
            payloads = try await ExportEntryBatchRenderer.renderAll(
                jobs: jobs,
                photoLibrary: photoLibrary,
                counter: nil,
            )
        } catch is CancellationError {
            return []
        }
        var urls: [URL] = []
        for payload in payloads {
            let fileName = ExportTempFileWriter.sanitizedName(from: payload.entry.relativeName)
            if let url = ExportTempFileWriter.write(
                data: payload.data,
                fileName: fileName,
                tempDirectory: tempDir,
            ) {
                urls.append(url)
            }
        }
        return urls
    }

    func loadPairs() async throws -> [PhotoPair] {
        try await pairRepo.fetch(ids: pairIds)
    }

    func recordExportHistory(
        identifier: String,
        pairId: UUID,
        entry: ExportSelection.Entry,
        renderOptions: ExportRenderOptions,
    ) async {
        guard
            let kind = ExportHistoryKindResolver.resolve(
                entryKind: entry.kind,
                renderOptions: renderOptions,
                appSettings: appSettings,
            )
        else { return }
        do {
            try await pairRepo.recordExportHistory(
                pairId: pairId,
                kind: kind,
                photoLocalIdentifier: identifier,
            )
        } catch {}
    }
}
