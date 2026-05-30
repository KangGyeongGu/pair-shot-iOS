import Foundation

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
    let logoStore: WatermarkLogoStore

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
        logoStore: WatermarkLogoStore = WatermarkLogoStore(),
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
        self.logoStore = logoStore
        self.tempDirectoryProvider = tempDirectoryProvider
    }

    func makeShareItems(for pairs: [PhotoPair]) async throws -> ExportShareItems {
        let selection = currentSelection()
        guard hasAnyInclude else {
            return ExportShareItems(values: [])
        }
        let token = "share-\(UUID().uuidString)"
        let handle = snackbarQueue.enqueueProgress(
            .share,
            token: token,
            initialValue: 0,
        )
        do {
            switch preferences.format {
                case .zip:
                    let url = try await exportPairs(
                        ids: pairs.map(\.id),
                        selection: selection,
                        renderOptions: currentRenderOptions(),
                        tempDirectory: tempDirectoryProvider(),
                        onProgress: makeZipProgressCallback(handle: handle),
                    )
                    snackbarQueue.completeProgress(handle)
                    return ExportShareItems(values: [url])

                case .individualImages:
                    let urls = await ExportSaveEngine.collectIndividualSourceURLs(
                        pairs: pairs,
                        selection: selection,
                        renderOptions: currentRenderOptions(),
                        context: ExportSaveSourceContext(
                            tempDirectory: tempDirectoryProvider(),
                            appSettings: appSettings,
                            photoLibrary: photoLibrary,
                            logoStore: logoStore,
                        ),
                    )
                    snackbarQueue.completeProgress(handle)
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
                .nothingToSave,
                debounceKey: "save-nothing",
            )
            return .completed
        }
        let token = "save-\(UUID().uuidString)"
        switch preferences.format {
            case .individualImages:
                let handle = snackbarQueue.enqueueProgress(
                    .saveToPhotos,
                    token: token,
                    initialValue: 0,
                )
                await saveImagesToPhotoLibrary(pairs: pairs, progress: handle)
                return .completed

            case .zip:
                let handle = snackbarQueue.enqueueProgress(
                    .prepareZipExport,
                    token: token,
                    initialValue: 0,
                )
                return await prepareZipForExport(pairs: pairs, progress: handle)
        }
    }

    func finishZipExport(url: URL, progress: SnackbarProgressHandle, saved: Bool) {
        if saved {
            snackbarQueue.completeProgress(
                progress,
                finalReason: .savedZip,
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
            .shareFailed,
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

    func currentRenderOptions() -> ExportRenderOptions {
        ExportRenderOptions(
            applyCombineSettings: preferences.applyCombineSettings,
            isPro: membership?.proIsActive ?? false,
        )
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
                onProgress: makeZipProgressCallback(handle: progress),
            )
            return .zipPendingExport(url: url, progress: progress)
        } catch {
            snackbarQueue.cancelProgress(progress)
            snackbarQueue.enqueue(
                .saveFailed,
                debounceKey: "save-failure",
            )
            return .completed
        }
    }

    private func makeZipProgressCallback(
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
}
