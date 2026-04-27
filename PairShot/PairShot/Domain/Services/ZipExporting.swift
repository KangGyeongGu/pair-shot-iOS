import Foundation

nonisolated enum ExportContents: String, Equatable, CaseIterable {
    case all
    case beforeOnly
    case afterOnly
    case combinedOnly
}

nonisolated enum ExportFormat: String, Equatable, CaseIterable {
    case zip
    case individualImages
}

protocol ZipExporting: Sendable {
    func exportPairsToZip(
        pairIds: [UUID],
        selection: ExportContents,
        in tempDirectory: URL,
        now: Date
    ) async throws -> URL
}
