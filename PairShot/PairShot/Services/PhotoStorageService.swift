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
