import Foundation
import SwiftData
import ZIPFoundation

/// P7.1 — Bundle a set of `PhotoPair`s into a single `.zip` archive that the
/// share sheet can hand off to Mail / Files / AirDrop / etc.
///
/// **Architecture**: ZIPFoundation's `Archive` is *not* `Sendable` and its
/// file-IO is best serialized; an `actor` makes the boundary explicit so two
/// concurrent share-sheet invocations can't trample each other's archive
/// handle. All disk-touching work happens off the MainActor.
///
/// **Layout**: archive entries are namespaced under `<projectTitle>/` so a
/// downstream user receiving the ZIP gets a single folder per project even
/// when they pick pairs from multiple projects (today the gallery is
/// per-project; the directory still keeps the pair metadata grouped).
///
/// **No lossy work**: the JPEGs are added byte-for-byte from disk — there's
/// no re-encode, no resize, no metadata stripping. The ZIP container itself
/// is uncompressed (`.none`) because JPEG is already entropy-coded; spending
/// CPU on DEFLATE here would only slow exports without shrinking the file.
actor ZipExporter {
    /// Errors surfaced to the caller (UI shows a toast).
    enum ExportError: Error, Equatable {
        /// `pairs` was empty — nothing to write.
        case noPairs
        /// `PhotoStorageService.resolve(...)` returned nil for a referenced path.
        case sourceMissing(String)
        /// Wrapped error from ZIPFoundation when initializing or appending.
        case archiveFailed
    }

    /// Default init — kept simple so call-sites can `ZipExporter()` inline.
    init() {}

    /// Produce a ZIP at `<tempDirectory>/PairShot_<yyyyMMdd_HHmmss>.zip`
    /// containing the JPEGs selected by `mode` for each pair.
    ///
    /// - Parameters:
    ///   - pairs: source `PhotoPair`s. **Read-only**; this function never
    ///     mutates SwiftData.
    ///   - mode: which of Before/After/Combined to include per pair.
    ///   - storage: resolves relative paths to absolute file URLs.
    ///   - tempDirectory: parent folder for the produced ZIP. Caller owns
    ///     cleanup (typically `FileManager.default.temporaryDirectory`).
    ///   - now: clock seam for the timestamped filename (tests inject).
    /// - Returns: absolute URL of the created ZIP, suitable for handing to
    ///   `UIActivityViewController` as an activity item.
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
                guard let absolute = storage.resolve(relativePath: entry.sourcePath) else {
                    throw ExportError.sourceMissing(entry.sourcePath)
                }
                guard FileManager.default.fileExists(atPath: absolute.path) else {
                    throw ExportError.sourceMissing(entry.sourcePath)
                }
                do {
                    // `compressionMethod = .none` since JPEGs don't gain from DEFLATE.
                    // `bufferSize` is the ZIPFoundation default 32 KiB chunk size —
                    // honoured by passing nothing (we drop the param to use default).
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

    /// `PairShot_20260426_153012.zip` — collation-friendly, no spaces.
    static func makeFileName(now: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "PairShot_\(formatter.string(from: now)).zip"
    }
}

/// Which JPEGs to bundle per `PhotoPair`. Surfaced in the export picker UI as
/// a segmented control. `combinedOnly` is meaningless for pairs that don't
/// have a composite yet — `ExportSelection.relativePaths` simply returns an
/// empty list and the pair is skipped.
enum ExportMode: String, CaseIterable, Identifiable {
    case all
    case beforeOnly
    case afterOnly
    case combinedOnly

    var id: String {
        rawValue
    }

    /// Korean label for the picker.
    var label: String {
        switch self {
            case .all: String(localized: "전체")
            case .beforeOnly: String(localized: "Before")
            case .afterOnly: String(localized: "After")
            case .combinedOnly: String(localized: "합성")
        }
    }
}

/// Pure decision: which of a `PhotoPair`'s JPEG paths get included for a given
/// `ExportMode`, and what the entry name in the archive should be.
///
/// Pulled out of `ZipExporter` so the policy is unit-testable without the
/// actor / file-IO involvement (and reusable later for direct save-to-photo
/// library or share-as-images flows).
enum ExportSelection {
    /// One archive entry to write.
    struct Entry: Equatable {
        /// Path inside the archive — uses `<projectTitle>/<pairUUID>_<role>.jpg`.
        let relativeName: String
        /// `PhotoPair`-stored relative path (`photos/<UUID>.jpg`) to read from.
        let sourcePath: String
    }

    /// - Returns: zero or more entries depending on `mode` and which optional
    ///   paths the pair carries (`afterPath` / `combinedPath` may be nil).
    static func relativePaths(for pair: PhotoPair, mode: ExportMode) -> [Entry] {
        let folder = sanitizeFolderName(pair.project?.title ?? "PairShot")
        let stem = pair.id.uuidString
        var out: [Entry] = []

        switch mode {
            case .all:
                out.append(Entry(
                    relativeName: "\(folder)/\(stem)_before.jpg",
                    sourcePath: pair.beforePath
                ))
                if let after = pair.afterPath, !after.isEmpty {
                    out.append(Entry(
                        relativeName: "\(folder)/\(stem)_after.jpg",
                        sourcePath: after
                    ))
                }
                if let combined = pair.combinedPath, !combined.isEmpty {
                    out.append(Entry(
                        relativeName: "\(folder)/\(stem)_combined.jpg",
                        sourcePath: combined
                    ))
                }

            case .beforeOnly:
                out.append(Entry(
                    relativeName: "\(folder)/\(stem)_before.jpg",
                    sourcePath: pair.beforePath
                ))

            case .afterOnly:
                if let after = pair.afterPath, !after.isEmpty {
                    out.append(Entry(
                        relativeName: "\(folder)/\(stem)_after.jpg",
                        sourcePath: after
                    ))
                }

            case .combinedOnly:
                if let combined = pair.combinedPath, !combined.isEmpty {
                    out.append(Entry(
                        relativeName: "\(folder)/\(stem)_combined.jpg",
                        sourcePath: combined
                    ))
                }
        }
        return out
    }

    /// Folders inside ZIPs sometimes round-trip through OSes that don't
    /// tolerate `/`, `\`, `:`, control chars, etc. Replace anything outside a
    /// safe ASCII / hangul / digit / underscore / dash set with `_`.
    static func sanitizeFolderName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "PairShot" }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "_-")
        // Also keep Hangul (Apple File Provider, Files.app, macOS Finder all
        // accept it) so Korean project titles aren't mangled in the archive.
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
