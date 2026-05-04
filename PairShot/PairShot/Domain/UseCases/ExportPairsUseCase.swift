import Foundation

struct ExportPairsUseCase {
    enum ExportError: Error, Equatable {
        case noPairs
    }

    let pairRepo: PhotoPairRepository
    let zipExporter: ZipExporterAdapter
    let now: @Sendable () -> Date

    init(
        pairRepo: PhotoPairRepository,
        zipExporter: ZipExporterAdapter,
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
        tempDirectory: URL = FileManager.default.temporaryDirectory
    ) async throws -> URL {
        guard !ids.isEmpty else { throw ExportError.noPairs }
        return try await zipExporter.exportPairsToZip(
            pairIds: ids,
            selection: selection,
            renderOptions: renderOptions,
            in: tempDirectory,
            now: now()
        )
    }
}
