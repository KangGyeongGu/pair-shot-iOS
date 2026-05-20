import Foundation

struct ExportPairsUseCase {
    enum ExportError: Error, Equatable {
        case noPairs
    }

    let zipExporter: ZipExporterAdapter
    let now: @Sendable () -> Date

    init(
        zipExporter: ZipExporterAdapter,
        now: @escaping @Sendable () -> Date = { .now },
    ) {
        self.zipExporter = zipExporter
        self.now = now
    }

    func callAsFunction(
        ids: [UUID],
        selection: ExportContents,
        renderOptions: ExportRenderOptions,
        tempDirectory: URL = FileManager.default.temporaryDirectory,
        onProgress: (@Sendable (_ fraction: Double, _ processed: Int, _ total: Int) -> Void)? = nil,
    ) async throws -> URL {
        guard !ids.isEmpty else { throw ExportError.noPairs }
        return try await zipExporter.exportPairsToZip(
            pairIds: ids,
            selection: selection,
            renderOptions: renderOptions,
            in: tempDirectory,
            now: now(),
            onProgress: onProgress,
        )
    }
}
