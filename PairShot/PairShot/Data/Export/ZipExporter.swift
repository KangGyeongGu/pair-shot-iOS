import Foundation
import ZIPFoundation

actor ZipExporter {
    enum ExportError: Error, Equatable {
        case noPairs
        case archiveFailed
    }

    init() {}

    func makeZip(
        for entries: [ZipEntryPayload],
        in tempDirectory: URL,
        now: Date = .now,
    ) async throws -> URL {
        guard !entries.isEmpty else { throw ExportError.noPairs }

        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
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

        for entry in entries {
            let payload = entry.data
            let modificationDate = entry.modificationDate ?? now
            do {
                try archive.addEntry(
                    with: entry.relativeName,
                    type: .file,
                    uncompressedSize: Int64(payload.count),
                    modificationDate: modificationDate,
                    compressionMethod: .none,
                    provider: { position, size in
                        let start = Int(position)
                        let end = min(start + size, payload.count)
                        guard start < end else { return Data() }
                        return payload.subdata(in: start ..< end)
                    },
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

nonisolated struct ZipEntryPayload {
    let relativeName: String
    let data: Data
    let modificationDate: Date?

    init(relativeName: String, data: Data, modificationDate: Date? = nil) {
        self.relativeName = relativeName
        self.data = data
        self.modificationDate = modificationDate
    }
}

nonisolated struct ZipExporterAdapter {
    let exporter: ZipExporter
    let photoLibrary: PhotoLibraryService
    let pairRepo: PhotoPairRepository
    let appSettings: AppSettings
    let logoStore: WatermarkLogoStore

    init(
        photoLibrary: PhotoLibraryService,
        pairRepo: PhotoPairRepository,
        appSettings: AppSettings,
        logoStore: WatermarkLogoStore = WatermarkLogoStore(),
        exporter: ZipExporter = ZipExporter(),
    ) {
        self.exporter = exporter
        self.photoLibrary = photoLibrary
        self.pairRepo = pairRepo
        self.appSettings = appSettings
        self.logoStore = logoStore
    }

    func exportPairsToZip(
        pairIds: [UUID],
        selection: ExportContents,
        renderOptions: ExportRenderOptions,
        in tempDirectory: URL,
        now: Date,
        onProgress: (@Sendable (_ fraction: Double, _ processed: Int, _ total: Int) -> Void)? = nil,
    ) async throws -> URL {
        let resolved = try await pairRepo.fetch(ids: pairIds)
        let logoStore = logoStore
        let jobs = await MainActor.run {
            ExportJobBuilder.makeJobs(
                pairs: resolved,
                selection: selection,
                appSettings: appSettings,
                renderOptions: renderOptions,
                logoStore: logoStore,
                now: now,
            )
        }
        let counter: ExportProgressCounter? = onProgress.map { update in
            ExportProgressCounter(total: max(jobs.count, 1)) { fraction, done, total in
                update(fraction, done, total)
            }
        }
        let payloads: [RenderedExportPayload]
        do {
            payloads = try await ExportEntryBatchRenderer.renderAll(
                jobs: jobs,
                photoLibrary: photoLibrary,
                counter: counter,
            )
        } catch is CancellationError {
            throw ZipExporter.ExportError.archiveFailed
        }
        var zipPayloads: [ZipEntryPayload] = []
        zipPayloads.reserveCapacity(payloads.count)
        for payload in payloads {
            zipPayloads.append(
                ZipEntryPayload(relativeName: payload.entry.relativeName, data: payload.data),
            )
        }
        return try await exporter.makeZip(for: zipPayloads, in: tempDirectory, now: now)
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
        let localIdentifier: String?
    }

    static func relativePaths(
        for pair: PhotoPair,
        selection: ExportContents,
        sequenceNumber: Int,
        prefix: String,
        fileExtension: String = "jpg",
    ) -> [Entry] {
        var out: [Entry] = []

        let beforeId = pair.beforePhotoLocalIdentifier
        let afterId = pair.afterPhotoLocalIdentifier
        let hasBefore = (beforeId?.isEmpty == false)
        let hasAfter = (afterId?.isEmpty == false)

        if selection.includeCombined, hasBefore, hasAfter {
            let fileName = FileNameBuilder.combined(
                prefix: prefix,
                timestamp: pair.createdAt,
                sequenceNumber: sequenceNumber,
                fileExtension: fileExtension,
            )
            out.append(
                Entry(
                    relativeName: "COMBINED/\(fileName)",
                    kind: .combined,
                    localIdentifier: nil,
                ),
            )
        }
        if selection.includeBefore, let beforeId, !beforeId.isEmpty {
            let fileName = FileNameBuilder.before(
                prefix: prefix,
                timestamp: pair.createdAt,
                sequenceNumber: sequenceNumber,
                fileExtension: fileExtension,
            )
            out.append(
                Entry(
                    relativeName: "BEFORE/\(fileName)",
                    kind: .before,
                    localIdentifier: beforeId,
                ),
            )
        }
        if selection.includeAfter, let afterId, !afterId.isEmpty {
            let fileName = FileNameBuilder.after(
                prefix: prefix,
                timestamp: pair.createdAt,
                sequenceNumber: sequenceNumber,
                fileExtension: fileExtension,
            )
            out.append(
                Entry(
                    relativeName: "AFTER/\(fileName)",
                    kind: .after,
                    localIdentifier: afterId,
                ),
            )
        }
        return out
    }
}
