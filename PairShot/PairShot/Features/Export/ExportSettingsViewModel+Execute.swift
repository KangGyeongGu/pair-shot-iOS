import Foundation
import OSLog
import Photos

extension ExportSettingsViewModel {
    func performShare() async {
        isExporting = true
        defer { isExporting = false }
        let token = "export-share-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            "snackbar_progress_share",
            token: token,
            initialValue: 0
        )
        do {
            switch format {
                case .zip:
                    snackbarQueue.updateProgress(handle, value: 0.3)
                    let url = try await exportPairs(
                        ids: pairIds,
                        selection: makeSelection(),
                        renderOptions: makeRenderOptions(),
                        tempDirectory: tempDirectoryProvider()
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
            initialValue: 0
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
            let allEntries = buildEntries(pairs: pairs, selection: selection)
            saved = await processEntries(
                allEntries,
                progress: progress,
                renderOptions: renderOptions,
                now: now
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

    func buildEntries(
        pairs: [PhotoPair],
        selection: ExportContents
    ) -> [(pair: PhotoPair, entry: ExportSelection.Entry)] {
        pairs.enumerated().flatMap { offset, pair in
            ExportSelection.relativePaths(
                for: pair,
                selection: selection,
                sequenceNumber: offset + 1,
                prefix: appSettings.fileNamePrefix
            )
            .map { (pair: pair, entry: $0) }
        }
    }

    func processEntries(
        _ allEntries: [(pair: PhotoPair, entry: ExportSelection.Entry)],
        progress: SnackbarProgressHandle,
        renderOptions: ExportRenderOptions,
        now: Date
    ) async -> Int {
        let total = max(1, allEntries.count)
        var saved = 0
        var processed = 0
        for item in allEntries {
            let didSave = await processSingleEntry(
                item: item,
                renderOptions: renderOptions,
                now: now
            )
            if didSave { saved += 1 }
            processed += 1
            snackbarQueue.updateProgress(progress, value: Double(processed) / Double(total))
        }
        return saved
    }

    func processSingleEntry(
        item: (pair: PhotoPair, entry: ExportSelection.Entry),
        renderOptions: ExportRenderOptions,
        now: Date
    ) async -> Bool {
        guard
            let data = await ExportEntryRenderer.render(
                entry: item.entry,
                pair: item.pair,
                photoLibrary: photoLibrary,
                appSettings: appSettings,
                renderOptions: renderOptions,
                now: now
            )
        else { return false }
        do {
            let identifier = try await photoLibraryExporter.saveImageData(data, type: .photo)
            await recordExportHistory(
                identifier: identifier,
                pair: item.pair,
                entry: item.entry,
                renderOptions: renderOptions
            )
            return true
        } catch {
            return false
        }
    }

    func finalizeSaveProgress(_ progress: SnackbarProgressHandle, savedCount: Int) {
        if savedCount == 0 {
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

    func saveZipToTemporaryAndNotify(progress: SnackbarProgressHandle) async {
        do {
            snackbarQueue.updateProgress(progress, value: 0.3)
            let url = try await exportPairs(
                ids: pairIds,
                selection: makeSelection(),
                renderOptions: makeRenderOptions(),
                tempDirectory: tempDirectoryProvider()
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
        var urls: [URL] = []
        let now = Date()
        for (offset, pair) in pairs.enumerated() {
            let entries = ExportSelection.relativePaths(
                for: pair,
                selection: selection,
                sequenceNumber: offset + 1,
                prefix: appSettings.fileNamePrefix
            )
            for entry in entries {
                guard
                    let data = await ExportEntryRenderer.render(
                        entry: entry,
                        pair: pair,
                        photoLibrary: photoLibrary,
                        appSettings: appSettings,
                        renderOptions: renderOptions,
                        now: now
                    )
                else { continue }
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

    func loadPairs() async throws -> [PhotoPair] {
        var resolved: [PhotoPair] = []
        for id in pairIds {
            if let pair = try await pairRepo.fetch(id: id) {
                resolved.append(pair)
            }
        }
        return resolved
    }

    func recordExportHistory(
        identifier: String,
        pair: PhotoPair,
        entry: ExportSelection.Entry,
        renderOptions: ExportRenderOptions
    ) async {
        guard
            let kind = ExportHistoryKindResolver.resolve(
                entryKind: entry.kind,
                renderOptions: renderOptions,
                appSettings: appSettings
            )
        else { return }
        do {
            try await pairRepo.recordExportHistory(
                pairId: pair.id,
                kind: kind,
                photoLocalIdentifier: identifier
            )
        } catch {
            AppLogger.storage.error(
                "ExportHistory persist failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
