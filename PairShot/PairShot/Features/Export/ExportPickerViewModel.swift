import Foundation
import Observation
import Photos

@MainActor
@Observable
final class ExportPickerViewModel {
    enum Event {
        case dismiss
        case toast(String)
    }

    let pairs: [PhotoPair]
    let storage: PhotoStorageService
    let events: AsyncStream<Event>

    var mode: ExportMode = .all
    var phase: ExportPickerPhase = .idle
    var error: ExportPickerError?
    var shareItems: ExportShareItems?

    var pairCount: Int {
        pairs.count
    }

    var isBusy: Bool {
        phase != .idle
    }

    var selectedContents: ExportContents {
        switch mode {
            case .all: .all
            case .beforeOnly: .beforeOnly
            case .afterOnly: .afterOnly
            case .combinedOnly: .combinedOnly
        }
    }

    private var pendingZipURL: URL?

    private let exportPairs: ExportPairsUseCase
    private let photoLibrary: any PhotoLibraryExporting
    private let tempDirectoryProvider: @Sendable () -> URL
    private let eventsContinuation: AsyncStream<Event>.Continuation

    init(
        pairs: [PhotoPair],
        storage: PhotoStorageService,
        exportPairs: ExportPairsUseCase,
        photoLibrary: any PhotoLibraryExporting,
        tempDirectoryProvider: @escaping @Sendable () -> URL = { FileManager.default.temporaryDirectory }
    ) {
        self.pairs = pairs
        self.storage = storage
        self.exportPairs = exportPairs
        self.photoLibrary = photoLibrary
        self.tempDirectoryProvider = tempDirectoryProvider
        var continuation: AsyncStream<Event>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventsContinuation = continuation
    }

    func dismiss() {
        eventsContinuation.yield(.dismiss)
    }

    func clearShareItems() {
        shareItems = nil
        cleanupPendingZip()
        dismiss()
    }

    func cleanupPendingZip() {
        guard let url = pendingZipURL else { return }
        pendingZipURL = nil
        try? FileManager.default.removeItem(at: url)
    }

    func shareAsZip() async {
        guard phase == .idle else { return }
        phase = .zipping
        defer { phase = .idle }
        do {
            let url = try await exportPairs(
                ids: pairs.map(\.id),
                selection: selectedContents,
                format: .zip,
                tempDirectory: tempDirectoryProvider()
            )
            pendingZipURL = url
            shareItems = ExportShareItems(values: [url])
        } catch let err as ZipExporter.ExportError {
            error = ExportPickerError.from(zipError: err)
        } catch let err as ExportPairsUseCase.ExportError {
            error = ExportPickerError.from(useCaseError: err)
        } catch {
            self.error = ExportPickerError(message: String(localized: "ZIP 생성에 실패했습니다"))
        }
    }

    func saveToPhotoLibrary() async {
        guard phase == .idle else { return }
        phase = .savingToLibrary
        defer { phase = .idle }
        let entries = pairs.flatMap { ExportSelection.relativePaths(for: $0, mode: mode) }
        let status = await photoLibrary.authorize()
        guard status == .authorized || status == .limited else {
            error = ExportPickerError(
                message: String(localized: "사진 라이브러리 권한이 필요합니다")
            )
            return
        }
        var saved = 0
        for entry in entries {
            guard
                let url = storage.resolve(kind: entry.sourceKind, fileName: entry.sourceFileName),
                let data = try? Data(contentsOf: url)
            else { continue }
            do {
                try await photoLibrary.saveImageData(data, type: .photo)
                saved += 1
            } catch PhotoLibraryExportError.notAuthorized {
                error = ExportPickerError(
                    message: String(localized: "사진 라이브러리 권한이 필요합니다")
                )
                return
            } catch {
                self.error = ExportPickerError(
                    message: String(localized: "저장 중 오류가 발생했습니다")
                )
                return
            }
        }
        eventsContinuation.yield(.toast(String(format: String(localized: "%d장 저장됨"), saved)))
        try? await Task.sleep(nanoseconds: 700_000_000)
        dismiss()
    }

    func shareAsImages() async {
        guard phase == .idle else { return }
        phase = .preparingImages
        defer { phase = .idle }
        let entries = pairs.flatMap { ExportSelection.relativePaths(for: $0, mode: mode) }
        var urls: [URL] = []
        for entry in entries {
            guard
                let url = storage.resolve(kind: entry.sourceKind, fileName: entry.sourceFileName),
                FileManager.default.fileExists(atPath: url.path)
            else { continue }
            urls.append(url)
        }
        guard !urls.isEmpty else {
            error = ExportPickerError(message: String(localized: "공유할 이미지가 없습니다"))
            return
        }
        shareItems = ExportShareItems(values: urls)
    }

    deinit {}
}
