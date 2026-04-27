import Foundation
import Observation
import Photos

struct ExportShareItems: Identifiable {
    let id = UUID()
    let values: [Any]
}

@MainActor
@Observable
final class ExportSettingsViewModel {
    enum Event {
        case dismiss
    }

    let pairIds: [UUID]
    let albumId: UUID?
    let events: AsyncStream<Event>

    var includeCombined: Bool = true
    var includeBefore: Bool = false
    var includeAfter: Bool = false
    var format: ExportFormat = .individualImages
    var applyWatermark: Bool = false
    var applyCombineSettings: Bool = false

    var isExporting: Bool = false
    var errorMessage: LocalizedStringResource?
    var shareItems: ExportShareItems?

    var hasAnyInclude: Bool {
        includeCombined || includeBefore || includeAfter
    }

    var canExecute: Bool {
        !isExporting && hasAnyInclude && !pairIds.isEmpty
    }

    private let pairRepo: PhotoPairRepository
    private let storage: PhotoStorageService
    private let exportPairs: ExportPairsUseCase
    private let photoLibrary: any PhotoLibraryExporting
    private let snackbarQueue: SnackbarQueue
    private let tempDirectoryProvider: @Sendable () -> URL
    private let eventsContinuation: AsyncStream<Event>.Continuation

    private var pendingZipURL: URL?

    init(
        pairIds: [UUID],
        albumId: UUID?,
        pairRepo: PhotoPairRepository,
        storage: PhotoStorageService,
        exportPairs: ExportPairsUseCase,
        photoLibrary: any PhotoLibraryExporting,
        snackbarQueue: SnackbarQueue,
        tempDirectoryProvider: @escaping @Sendable () -> URL = { FileManager.default.temporaryDirectory }
    ) {
        self.pairIds = pairIds
        self.albumId = albumId
        self.pairRepo = pairRepo
        self.storage = storage
        self.exportPairs = exportPairs
        self.photoLibrary = photoLibrary
        self.snackbarQueue = snackbarQueue
        self.tempDirectoryProvider = tempDirectoryProvider
        var continuation: AsyncStream<Event>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventsContinuation = continuation
    }

    func cleanupPendingZip() {
        guard let url = pendingZipURL else { return }
        pendingZipURL = nil
        try? FileManager.default.removeItem(at: url)
    }

    func clearShareItems() {
        shareItems = nil
        cleanupPendingZip()
        eventsContinuation.yield(.dismiss)
    }

    func share() async {
        guard canExecute else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            switch format {
                case .zip:
                    let url = try await exportPairs(
                        ids: pairIds,
                        selection: makeSelection(),
                        format: .zip,
                        tempDirectory: tempDirectoryProvider()
                    )
                    pendingZipURL = url
                    shareItems = ExportShareItems(values: [url])

                case .individualImages:
                    let urls = try await collectIndividualSourceURLs()
                    guard !urls.isEmpty else {
                        errorMessage = "snackbar_error_share_failed"
                        return
                    }
                    shareItems = ExportShareItems(values: urls)
            }
        } catch {
            errorMessage = "snackbar_error_share_failed"
        }
    }

    func saveToDevice() async {
        guard canExecute else { return }
        isExporting = true
        defer { isExporting = false }
        switch format {
            case .individualImages:
                await saveImagesToPhotoLibrary()

            case .zip:
                await saveZipToTemporaryAndNotify()
        }
    }

    private func saveImagesToPhotoLibrary() async {
        let status = await photoLibrary.authorize()
        guard status == .authorized || status == .limited else {
            errorMessage = "snackbar_error_save_failed"
            return
        }
        var saved = 0
        do {
            let pairs = try await loadPairs()
            let mode = makeMode()
            let entries = pairs.flatMap { ExportSelection.relativePaths(for: $0, mode: mode) }
            for entry in entries {
                guard
                    let url = storage.resolve(kind: entry.sourceKind, fileName: entry.sourceFileName),
                    let data = try? Data(contentsOf: url)
                else { continue }
                try await photoLibrary.saveImageData(data, type: .photo)
                saved += 1
            }
        } catch {
            errorMessage = "snackbar_error_save_failed"
            return
        }
        if saved == 0 {
            snackbarQueue.enqueue(
                "snackbar_warning_nothing_to_save",
                variant: .warning,
                debounceKey: "save-nothing"
            )
        } else {
            snackbarQueue.enqueue(
                "snackbar_success_saved_to_device",
                variant: .success,
                debounceKey: "save-success"
            )
        }
        eventsContinuation.yield(.dismiss)
    }

    private func saveZipToTemporaryAndNotify() async {
        do {
            let url = try await exportPairs(
                ids: pairIds,
                selection: makeSelection(),
                format: .zip,
                tempDirectory: tempDirectoryProvider()
            )
            pendingZipURL = url
            snackbarQueue.enqueue(
                "snackbar_success_saved_zip",
                variant: .success,
                debounceKey: "save-zip"
            )
            eventsContinuation.yield(.dismiss)
        } catch {
            errorMessage = "snackbar_error_save_failed"
        }
    }

    private func collectIndividualSourceURLs() async throws -> [URL] {
        let pairs = try await loadPairs()
        let mode = makeMode()
        let entries = pairs.flatMap { ExportSelection.relativePaths(for: $0, mode: mode) }
        var urls: [URL] = []
        for entry in entries {
            guard
                let url = storage.resolve(kind: entry.sourceKind, fileName: entry.sourceFileName),
                FileManager.default.fileExists(atPath: url.path)
            else { continue }
            urls.append(url)
        }
        return urls
    }

    private func loadPairs() async throws -> [PhotoPair] {
        var resolved: [PhotoPair] = []
        for id in pairIds {
            if let pair = try await pairRepo.fetch(id: id) {
                resolved.append(pair)
            }
        }
        return resolved
    }

    private func makeSelection() -> ExportContents {
        ExportContentsMapping.fromIncludes(
            combined: includeCombined,
            before: includeBefore,
            after: includeAfter
        )
    }

    private func makeMode() -> ExportMode {
        ExportContentsMapping.toMode(makeSelection())
    }

    deinit {}
}

extension ExportContentsMapping {
    static func fromIncludes(combined: Bool, before: Bool, after: Bool) -> ExportContents {
        let count = [combined, before, after].count(where: { $0 })
        if count >= 2 { return .all }
        if combined { return .combinedOnly }
        if before { return .beforeOnly }
        if after { return .afterOnly }
        return .all
    }
}
