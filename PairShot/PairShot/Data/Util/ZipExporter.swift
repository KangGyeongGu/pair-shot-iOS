import Foundation
import SwiftData
import ZIPFoundation

actor ZipExporter {
    enum ExportError: Error, Equatable {
        case noPairs
        case sourceMissing(String)
        case archiveFailed
    }

    init() {}

    func makeZip(
        for pairs: [PhotoPair],
        mode: ExportMode,
        storage: PhotoStorageService,
        in tempDirectory: URL,
        now: Date = .now
    ) async throws -> URL {
        guard !pairs.isEmpty else { throw ExportError.noPairs }

        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        let zipURL = tempDirectory.appendingPathComponent(Self.makeFileName(now: now))
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try? FileManager.default.removeItem(at: zipURL)
        }

        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .create)
        } catch {
            throw ExportError.archiveFailed
        }

        for pair in pairs {
            let entries = ExportSelection.relativePaths(for: pair, mode: mode)
            for entry in entries {
                guard let absolute = storage.resolve(kind: entry.sourceKind, fileName: entry.sourceFileName) else {
                    throw ExportError.sourceMissing(entry.sourceFileName)
                }
                guard FileManager.default.fileExists(atPath: absolute.path) else {
                    throw ExportError.sourceMissing(entry.sourceFileName)
                }
                do {
                    try archive.addEntry(
                        with: entry.relativeName,
                        fileURL: absolute,
                        compressionMethod: .none
                    )
                } catch {
                    throw ExportError.archiveFailed
                }
            }
        }

        return zipURL
    }

    static func makeFileName(now: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "PairShot_\(formatter.string(from: now)).zip"
    }
}

struct ZipExporterAdapter: ZipExporting {
    let exporter: ZipExporter
    let storage: PhotoStorageService
    let pairRepo: PhotoPairRepository

    init(
        exporter: ZipExporter = ZipExporter(),
        storage: PhotoStorageService,
        pairRepo: PhotoPairRepository
    ) {
        self.exporter = exporter
        self.storage = storage
        self.pairRepo = pairRepo
    }

    func exportPairsToZip(
        pairIds: [UUID],
        selection: ExportContents,
        in tempDirectory: URL,
        now: Date
    ) async throws -> URL {
        var resolved: [PhotoPair] = []
        for id in pairIds {
            if let pair = try await pairRepo.fetch(id: id) {
                resolved.append(pair)
            }
        }
        return try await exporter.makeZip(
            for: resolved,
            mode: ExportContentsMapping.toMode(selection),
            storage: storage,
            in: tempDirectory,
            now: now
        )
    }
}

nonisolated enum ExportContentsMapping {
    static func toMode(_ contents: ExportContents) -> ExportMode {
        switch contents {
            case .all: .all
            case .beforeOnly: .beforeOnly
            case .afterOnly: .afterOnly
            case .combinedOnly: .combinedOnly
        }
    }
}

nonisolated enum ExportMode: String, CaseIterable, Identifiable {
    case all
    case beforeOnly
    case afterOnly
    case combinedOnly

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
            case .all: String(localized: "home_filter_all")
            case .beforeOnly: String(localized: "Before")
            case .afterOnly: String(localized: "After")
            case .combinedOnly: String(localized: "settings_section_combine")
        }
    }
}

nonisolated enum ExportSelection {
    nonisolated struct Entry: Equatable {
        let relativeName: String
        let sourceKind: PhotoStorageService.PhotoKind
        let sourceFileName: String
    }

    static func relativePaths(for pair: PhotoPair, mode: ExportMode) -> [Entry] {
        let albumName = pair.albums.first?.name
        let folder = sanitizeFolderName(albumName ?? "PairShot")
        var out: [Entry] = []

        switch mode {
            case .all:
                out.append(Entry(
                    relativeName: "\(folder)/BEFORE/\(pair.beforeFileName)",
                    sourceKind: .before,
                    sourceFileName: pair.beforeFileName
                ))
                if let after = pair.afterFileName, !after.isEmpty {
                    out.append(Entry(
                        relativeName: "\(folder)/AFTER/\(after)",
                        sourceKind: .after,
                        sourceFileName: after
                    ))
                }
                if let combined = pair.combinedFileName, !combined.isEmpty {
                    out.append(Entry(
                        relativeName: "\(folder)/COMBINED/\(combined)",
                        sourceKind: .combined,
                        sourceFileName: combined
                    ))
                }

            case .beforeOnly:
                out.append(Entry(
                    relativeName: "\(folder)/BEFORE/\(pair.beforeFileName)",
                    sourceKind: .before,
                    sourceFileName: pair.beforeFileName
                ))

            case .afterOnly:
                if let after = pair.afterFileName, !after.isEmpty {
                    out.append(Entry(
                        relativeName: "\(folder)/AFTER/\(after)",
                        sourceKind: .after,
                        sourceFileName: after
                    ))
                }

            case .combinedOnly:
                if let combined = pair.combinedFileName, !combined.isEmpty {
                    out.append(Entry(
                        relativeName: "\(folder)/COMBINED/\(combined)",
                        sourceKind: .combined,
                        sourceFileName: combined
                    ))
                }
        }
        return out
    }

    static func sanitizeFolderName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "PairShot" }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "_-")
        allowed.insert(charactersIn: Unicode.Scalar(0xAC00)! ... Unicode.Scalar(0xD7A3)!)
        var out = ""
        out.reserveCapacity(trimmed.count)
        for scalar in trimmed.unicodeScalars {
            if allowed.contains(scalar) {
                out.unicodeScalars.append(scalar)
            } else {
                out.append("_")
            }
        }
        return out.isEmpty ? "PairShot" : out
    }
}
