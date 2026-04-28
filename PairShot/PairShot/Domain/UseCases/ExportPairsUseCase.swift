import Foundation

struct ExportPairsUseCase {
    enum ExportError: Error, Equatable {
        case noPairs
        case unsupportedFormat
    }

    let pairRepo: PhotoPairRepository
    let zipExporter: ZipExporting
    let now: @Sendable () -> Date

    init(
        pairRepo: PhotoPairRepository,
        zipExporter: ZipExporting,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.pairRepo = pairRepo
        self.zipExporter = zipExporter
        self.now = now
    }

    func callAsFunction(
        ids: [UUID],
        selection: ExportContents,
        renderOptions: ExportRenderOptions,
        format: ExportFormat,
        tempDirectory: URL = FileManager.default.temporaryDirectory
    ) async throws -> URL {
        guard !ids.isEmpty else { throw ExportError.noPairs }
        switch format {
            case .zip:
                return try await zipExporter.exportPairsToZip(
                    pairIds: ids,
                    selection: selection,
                    renderOptions: renderOptions,
                    in: tempDirectory,
                    now: now()
                )

            case .individualImages:
                throw ExportError.unsupportedFormat
        }
    }
}
