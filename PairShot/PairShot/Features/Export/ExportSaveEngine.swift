import Foundation
import Photos

@MainActor
struct ExportSaveDependencies {
    let snackbarQueue: SnackbarQueue
    let photoLibrary: PhotoLibraryService
    let photoLibraryExporter: PhotoLibraryExport
    let pairRepo: PhotoPairRepository
    let appSettings: AppSettings
}

@MainActor
enum ExportSaveEngine {
    static func processJobs(
        _ jobs: [ExportJob],
        renderOptions: ExportRenderOptions,
        progress: SnackbarProgressHandle,
        deps: ExportSaveDependencies,
        onRenderOrSaveFailure: (@MainActor (SnackbarProgressHandle) -> Void)? = nil,
    ) async -> Int {
        let totalJobs = max(1, jobs.count)
        let snackbar = deps.snackbarQueue
        let progressToken = progress.token
        let counter = ExportProgressCounter(
            total: ExportSaveProgressMapping.ticksTotal(jobs: totalJobs),
        ) { fraction, done, _ in
            Task { @MainActor in
                let processed = ExportSaveProgressMapping.processed(done: done, jobsTotal: totalJobs)
                snackbar.updateProgress(
                    SnackbarProgressHandle(token: progressToken),
                    value: fraction,
                    processed: processed,
                    total: totalJobs,
                )
            }
        }
        let payloads: [RenderedExportPayload]
        do {
            payloads = try await ExportEntryBatchRenderer.renderAll(
                jobs: jobs,
                photoLibrary: deps.photoLibrary,
                counter: counter,
            )
        } catch is CancellationError {
            return 0
        } catch {
            onRenderOrSaveFailure?(progress)
            return 0
        }
        var saved = 0
        for payload in payloads {
            do {
                let identifier = try await deps.photoLibraryExporter.saveImageData(
                    payload.data,
                    type: .photo,
                    utType: payload.utType,
                )
                await recordExportHistory(
                    identifier: identifier,
                    pairId: payload.pairId,
                    entry: payload.entry,
                    renderOptions: renderOptions,
                    pairRepo: deps.pairRepo,
                    appSettings: deps.appSettings,
                )
                saved += 1
                await counter.tick()
            } catch {
                onRenderOrSaveFailure?(progress)
                return saved
            }
        }
        return saved
    }

    static func finalizeProgress(
        _ progress: SnackbarProgressHandle,
        savedCount: Int,
        snackbarQueue: SnackbarQueue,
    ) {
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

    static func recordExportHistory(
        identifier: String,
        pairId: UUID,
        entry: ExportSelection.Entry,
        renderOptions: ExportRenderOptions,
        pairRepo: PhotoPairRepository,
        appSettings: AppSettings,
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

    static func collectIndividualSourceURLs(
        pairs: [PhotoPair],
        selection: ExportContents,
        renderOptions: ExportRenderOptions,
        tempDirectory: URL,
        appSettings: AppSettings,
        photoLibrary: PhotoLibraryService,
        now: Date = Date(),
    ) async -> [URL] {
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
        } catch {
            return []
        }
        var urls: [URL] = []
        for payload in payloads {
            let fileName = ExportTempFileWriter.sanitizedName(from: payload.entry.relativeName)
            if let url = ExportTempFileWriter.write(
                data: payload.data,
                fileName: fileName,
                tempDirectory: tempDirectory,
            ) {
                urls.append(url)
            }
        }
        return urls
    }
}
