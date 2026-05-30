import Foundation
import Photos

extension ExportSettingsViewModel {
    func performShare() async {
        isExporting = true
        defer { isExporting = false }
        let token = "export-share-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            .share,
            token: token,
            initialValue: 0,
        )
        do {
            switch format {
                case .zip:
                    let url = try await exportPairs(
                        ids: pairIds,
                        selection: makeSelection(),
                        renderOptions: makeRenderOptions(),
                        tempDirectory: tempDirectoryProvider(),
                        onProgress: makeZipProgressCallback(handle: handle),
                    )
                    pendingZipURL = url
                    snackbarQueue.completeProgress(handle)
                    shareItems = ExportShareItems(values: [url])

                case .individualImages:
                    let urls = try await collectIndividualSourceURLs()
                    guard !urls.isEmpty else {
                        snackbarQueue.cancelProgress(handle)
                        errorMessage = "snackbar_shareFailed_body"
                        return
                    }
                    snackbarQueue.completeProgress(handle)
                    shareItems = ExportShareItems(values: urls)
            }
        } catch {
            snackbarQueue.cancelProgress(handle)
            errorMessage = "snackbar_shareFailed_body"
        }
    }

    func performSaveToDevice() async {
        isExporting = true
        defer { isExporting = false }
        let token = "export-save-\(UUID().uuidString)"
        switch format {
            case .individualImages:
                let handle = snackbarQueue.enqueueProgress(
                    .saveToPhotos,
                    token: token,
                    initialValue: 0,
                )
                await saveImagesToPhotoLibrary(progress: handle)

            case .zip:
                let handle = snackbarQueue.enqueueProgress(
                    .prepareZipExport,
                    token: token,
                    initialValue: 0,
                )
                await saveZipToTemporaryAndNotify(progress: handle)
        }
    }

    func saveImagesToPhotoLibrary(progress: SnackbarProgressHandle) async {
        let status = await photoLibraryExporter.authorize()
        guard status == .authorized || status == .limited else {
            snackbarQueue.cancelProgress(progress)
            errorMessage = "snackbar_saveFailed_body"
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
                logoStore: logoStore,
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
            errorMessage = "snackbar_saveFailed_body"
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
            let url = try await exportPairs(
                ids: pairIds,
                selection: makeSelection(),
                renderOptions: makeRenderOptions(),
                tempDirectory: tempDirectoryProvider(),
                onProgress: makeZipProgressCallback(handle: progress),
            )
            pendingZipURL = url
            zipSaveProgress = progress
            zipExportItem = DocumentExporterItem(url: url)
        } catch {
            snackbarQueue.cancelProgress(progress)
            errorMessage = "snackbar_saveFailed_body"
        }
    }

    func makeZipProgressCallback(
        handle: SnackbarProgressHandle,
    ) -> @Sendable (_ fraction: Double, _ processed: Int, _ total: Int) -> Void {
        let snackbar = snackbarQueue
        let token = handle.token
        return { fraction, processed, total in
            Task { @MainActor in
                snackbar.updateProgress(
                    SnackbarProgressHandle(token: token),
                    value: fraction,
                    processed: processed,
                    total: total,
                )
            }
        }
    }

    func collectIndividualSourceURLs() async throws -> [URL] {
        let pairs = try await loadPairs()
        return await ExportSaveEngine.collectIndividualSourceURLs(
            pairs: pairs,
            selection: makeSelection(),
            renderOptions: makeRenderOptions(),
            context: ExportSaveSourceContext(
                tempDirectory: tempDirectoryProvider(),
                appSettings: appSettings,
                photoLibrary: photoLibrary,
                logoStore: logoStore,
            ),
        )
    }

    func loadPairs() async throws -> [PhotoPair] {
        try await pairRepo.fetch(ids: pairIds)
    }
}
