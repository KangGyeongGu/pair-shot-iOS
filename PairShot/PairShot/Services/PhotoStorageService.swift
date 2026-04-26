import Foundation

/// Persists captured JPEGs to the app container and produces relative paths
/// suitable for storing in `PhotoPair.beforePath` / `.afterPath`.
///
/// All photos live under
/// `Application Support/photos/<UUID>.jpg` and the path stored in SwiftData
/// is `photos/<UUID>.jpg` (relative). Resolving back to an absolute URL is
/// `resolve(relativePath:)`.
///
/// All members are `nonisolated` so the type can be consumed off the main
/// actor (e.g. inside `CameraSession`).
struct PhotoStorageService {
    /// Subdirectory inside `Application Support` where JPEGs land.
    static let photosDirectoryName = "photos"

    /// Optional injection seam for tests — swap out the base directory.
    let baseDirectory: URL

    nonisolated init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = (try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? URL.documentsDirectory
        }
    }

    /// Folder where JPEGs are stored. Created lazily on first call.
    nonisolated var photosDirectory: URL {
        baseDirectory.appendingPathComponent(Self.photosDirectoryName, isDirectory: true)
    }

    /// Writes `jpegData` to `photos/<prefix><UUID>.jpg` and returns the
    /// relative path for storage in `PhotoPair.beforePath`. P8.2 added the
    /// optional `fileNamePrefix` so users can tag exports with a project
    /// or crew code; pass an empty string for the default behaviour.
    nonisolated func saveBeforeJPEG(
        _ jpegData: Data,
        fileID: UUID = UUID(),
        fileNamePrefix: String = ""
    ) throws -> String {
        try writeJPEG(jpegData, fileID: fileID, fileNamePrefix: fileNamePrefix)
    }

    /// Writes `jpegData` to `photos/<prefix><UUID>.jpg` and returns the
    /// relative path for storage in `PhotoPair.afterPath`. Same on-disk
    /// shape as ``saveBeforeJPEG(_:fileID:fileNamePrefix:)``; the
    /// before/after distinction is encoded by the calling field, not the
    /// filename.
    nonisolated func saveAfterJPEG(
        _ jpegData: Data,
        fileID: UUID = UUID(),
        fileNamePrefix: String = ""
    ) throws -> String {
        try writeJPEG(jpegData, fileID: fileID, fileNamePrefix: fileNamePrefix)
    }

    /// Writes `jpegData` to `photos/<prefix><UUID>.jpg` and returns the
    /// relative path for storage in `PhotoPair.combinedPath`. P5.2
    /// composite renderer.
    nonisolated func saveCombinedJPEG(
        _ jpegData: Data,
        fileID: UUID = UUID(),
        fileNamePrefix: String = ""
    ) throws -> String {
        try writeJPEG(jpegData, fileID: fileID, fileNamePrefix: fileNamePrefix)
    }

    /// Resolves a relative path produced by `saveBeforeJPEG` back to an
    /// absolute URL. Returns `nil` if `relativePath` is blank.
    nonisolated func resolve(relativePath: String) -> URL? {
        guard !relativePath.isEmpty else { return nil }
        return baseDirectory.appendingPathComponent(relativePath, isDirectory: false)
    }

    /// Deletes a JPEG by its `PhotoPair`-stored relative path. No-op if missing.
    nonisolated func deletePhoto(at relativePath: String) throws {
        guard let url = resolve(relativePath: relativePath) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - P8.4 — directory size & orphan cleanup

    /// Sum of bytes occupied by every regular file under ``photosDirectory``.
    /// Returns 0 if the directory hasn't been created yet (fresh install).
    ///
    /// Uses `URL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])`
    /// per Apple's recommendation for accurate on-disk usage (vs. the
    /// logical size returned by `FileManager.attributesOfItem`).
    nonisolated func directorySize() throws -> Int64 {
        let dir = photosDirectory
        guard FileManager.default.fileExists(atPath: dir.path) else { return 0 }
        var total: Int64 = 0
        for url in try enumerateAllFiles() {
            let values = try url.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .fileSizeKey,
            ])
            // Prefer allocated size (what the filesystem reserved); fall
            // back to logical size for filesystems that don't report it.
            let bytes = values.totalFileAllocatedSize
                ?? values.fileAllocatedSize
                ?? values.fileSize
                ?? 0
            total += Int64(bytes)
        }
        return total
    }

    /// Lists every regular file under ``photosDirectory``. Returns an
    /// empty array if the directory doesn't exist. Hidden + package
    /// descendants are skipped so we don't walk into eg. .DS_Store.
    nonisolated func enumerateAllFiles() throws -> [URL] {
        let dir = photosDirectory
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            if values.isRegularFile == true {
                files.append(url)
            }
        }
        return files
    }

    /// Subset of ``enumerateAllFiles()`` that no `PhotoPair`'s
    /// `beforePath` / `afterPath` / `combinedPath` references. Pure on
    /// the input set so the caller (settings UI) can compute the
    /// reference set with whichever SwiftData query suits it.
    nonisolated func orphanFiles(referencedRelativePaths: Set<String>) throws -> [URL] {
        let referencedFilenames = Set(
            referencedRelativePaths.compactMap { Self.filename(from: $0) }
        )
        let all = try enumerateAllFiles()
        return all.filter { url in
            !referencedFilenames.contains(url.lastPathComponent)
        }
    }

    /// Removes every file in ``orphanFiles(referencedRelativePaths:)``
    /// and returns `(count, bytes)` of what was deleted. Best-effort:
    /// individual removal failures are skipped so a single locked file
    /// doesn't abort the entire sweep.
    nonisolated func deleteOrphanFiles(
        referencedRelativePaths: Set<String>
    ) throws -> (deletedCount: Int, freedBytes: Int64) {
        let orphans = try orphanFiles(referencedRelativePaths: referencedRelativePaths)
        var deletedCount = 0
        var freedBytes: Int64 = 0
        for url in orphans {
            let size = (try? url.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .fileSizeKey,
            ]))
            .flatMap { $0.totalFileAllocatedSize ?? $0.fileAllocatedSize ?? $0.fileSize }
            ?? 0
            do {
                try FileManager.default.removeItem(at: url)
                deletedCount += 1
                freedBytes += Int64(size)
            } catch {
                // Best-effort sweep — skip files we can't remove.
                continue
            }
        }
        return (deletedCount, freedBytes)
    }

    /// Extracts the filename component from a stored relative path. Pure
    /// helper so tests can verify normalisation without instantiating
    /// the storage service.
    nonisolated static func filename(from relativePath: String) -> String? {
        guard !relativePath.isEmpty else { return nil }
        let last = (relativePath as NSString).lastPathComponent
        return last.isEmpty ? nil : last
    }

    private nonisolated func ensureDirectoryExists() throws {
        let dir = photosDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }
    }

    /// Shared writer for the three save entry points. Centralises the
    /// `<prefix><UUID>.jpg` filename pattern so future tweaks (eg. a date
    /// prefix) only touch one place. The `fileNamePrefix` is sanitised
    /// here defensively even though the typical call site already feeds
    /// ``FileNamePrefixValidator/sanitize(_:)`` output — hardening cheap.
    private nonisolated func writeJPEG(
        _ jpegData: Data,
        fileID: UUID,
        fileNamePrefix: String
    ) throws -> String {
        try ensureDirectoryExists()
        let safePrefix = FileNamePrefixValidator.sanitize(fileNamePrefix)
        let fileName = "\(safePrefix)\(fileID.uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try jpegData.write(to: fileURL, options: .atomic)
        return "\(Self.photosDirectoryName)/\(fileName)"
    }
}
