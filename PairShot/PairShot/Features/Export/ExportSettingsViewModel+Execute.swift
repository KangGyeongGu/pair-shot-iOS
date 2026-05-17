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
            saved = await ExportSaveEngine.processJobs(
                jobs,
                renderOptions: renderOptions,
                progress: progress,
                deps: ExportSaveDependencies(
                    snackbarQueue: snackbarQueue,
                    photoLibrary: photoLibrary,
                    photoLibraryExporter: photoLibraryExporter,
                    pairRepo: pairRepo,
                    appSettings: appSettings,
                ),
            )
        } catch {
            snackbarQueue.cancelProgress(progress)
            errorMessage = "snackbar_error_save_failed"
            return
        }
        ExportSaveEngine.finalizeProgress(
            progress,
            savedCount: saved,
            snackbarQueue: snackbarQueue,
        )
        eventsContinuation.yield(.completed)
        eventsContinuation.yield(.dismiss)
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
        return await ExportSaveEngine.collectIndividualSourceURLs(
            pairs: pairs,
            selection: makeSelection(),
            renderOptions: makeRenderOptions(),
            tempDirectory: tempDirectoryProvider(),
            appSettings: appSettings,
            photoLibrary: photoLibrary,
        )
    }

    func loadPairs() async throws -> [PhotoPair] {
        try await pairRepo.fetch(ids: pairIds)
    }
}
