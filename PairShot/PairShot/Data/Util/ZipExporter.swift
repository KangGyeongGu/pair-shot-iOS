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
        for entries: [ZipEntryPayload],
        in tempDirectory: URL,
        now: Date = .now
    ) async throws -> URL {
        guard !entries.isEmpty else { throw ExportError.noPairs }

        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        let zipURL = tempDirectory.appendingPathComponent(Self.makeFileName(now: now))
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try? FileManager.default.removeItem(at: zipURL)
        }

        let stagingDir = tempDirectory.appendingPathComponent(
            "pairshot-zip-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingDir) }

        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .create)
        } catch {
            throw ExportError.archiveFailed
        }

        for (index, entry) in entries.enumerated() {
            let stagedURL = stagingDir.appendingPathComponent("payload-\(index).bin")
            do {
                try entry.data.write(to: stagedURL, options: .atomic)
            } catch {
                throw ExportError.archiveFailed
            }
            do {
                try archive.addEntry(
                    with: entry.relativeName,
                    fileURL: stagedURL,
                    compressionMethod: .none
                )
            } catch {
                throw ExportError.archiveFailed
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

struct ZipEntryPayload {
    let relativeName: String
    let data: Data
}

@MainActor
struct ZipExporterAdapter: ZipExporting {
    let exporter: ZipExporter
    let photoLibrary: PhotoLibraryService
    let pairRepo: PhotoPairRepository
    let appSettings: AppSettings

    init(
        exporter: ZipExporter = ZipExporter(),
        photoLibrary: PhotoLibraryService,
        pairRepo: PhotoPairRepository,
        appSettings: AppSettings
    ) {
        self.exporter = exporter
        self.photoLibrary = photoLibrary
        self.pairRepo = pairRepo
        self.appSettings = appSettings
    }

    func exportPairsToZip(
        pairIds: [UUID],
        selection: ExportContents,
        renderOptions: ExportRenderOptions,
        in tempDirectory: URL,
        now: Date
    ) async throws -> URL {
        var resolved: [PhotoPair] = []
        for id in pairIds {
            if let pair = try await pairRepo.fetch(id: id) {
                resolved.append(pair)
            }
        }
        var payloads: [ZipEntryPayload] = []
        for pair in resolved {
            let entries = ExportSelection.relativePaths(
                for: pair,
                selection: selection,
                now: now
            )
            for entry in entries {
                guard let data = await ExportEntryRenderer.render(
                    entry: entry,
                    pair: pair,
                    photoLibrary: photoLibrary,
                    appSettings: appSettings,
                    renderOptions: renderOptions,
                    now: now
                ) else { continue }
                payloads.append(ZipEntryPayload(relativeName: entry.relativeName, data: data))
            }
        }
        return try await exporter.makeZip(for: payloads, in: tempDirectory, now: now)
    }
}

nonisolated enum ExportPhotoKind: String, Equatable {
    case before
    case after
    case combined
}

nonisolated enum ExportSelection {
    nonisolated struct Entry: Equatable {
        let relativeName: String
        let kind: ExportPhotoKind
        let pairId: UUID
        let localIdentifier: String?
    }

    static func relativePaths(
        for pair: PhotoPair,
        selection: ExportContents,
        now: Date = .now
    ) -> [Entry] {
        let albumName = pair.albums.first?.name
        let folder = sanitizeFolderName(albumName ?? "PairShot")
        let timestamp = makeTimestamp(now: now, pair: pair)
        var out: [Entry] = []

        let beforeId = pair.beforePhotoLocalIdentifier
        let afterId = pair.afterPhotoLocalIdentifier
        let hasBefore = (beforeId?.isEmpty == false)
        let hasAfter = (afterId?.isEmpty == false)

        if selection.includeCombined, hasBefore, hasAfter {
            out.append(Entry(
                relativeName: "\(folder)/COMBINED/\(timestamp)_PAIR.jpg",
                kind: .combined,
                pairId: pair.id,
                localIdentifier: nil
            ))
        }
        if selection.includeBefore, let beforeId, !beforeId.isEmpty {
            out.append(Entry(
                relativeName: "\(folder)/BEFORE/\(timestamp)_BEFORE.jpg",
                kind: .before,
                pairId: pair.id,
                localIdentifier: beforeId
            ))
        }
        if selection.includeAfter, let afterId, !afterId.isEmpty {
            out.append(Entry(
                relativeName: "\(folder)/AFTER/\(timestamp)_AFTER.jpg",
                kind: .after,
                pairId: pair.id,
                localIdentifier: afterId
            ))
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

    private static func makeTimestamp(now _: Date, pair: PhotoPair) -> String {
        let date = pair.createdAt
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: date)
        let suffix = String(pair.id.uuidString.prefix(8))
        return "\(stamp)_\(suffix)"
    }
}
