import Foundation
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
        let saved = await ExportSaveEngine.processJobs(
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
            onRenderOrSaveFailure: { [weak self] handle in
                self?.enqueueSaveFailure(progress: handle)
            },
        )
        ExportSaveEngine.finalizeProgress(
            progress,
            savedCount: saved,
            snackbarQueue: snackbarQueue,
        )
    }

    func enqueueSaveFailure(progress: SnackbarProgressHandle) {
        snackbarQueue.cancelProgress(progress)
        snackbarQueue.enqueue(
            "snackbar_error_save_failed",
            variant: .error,
            debounceKey: "save-failure",
        )
    }
}
