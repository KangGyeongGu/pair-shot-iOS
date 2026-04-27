import Foundation
import OSLog

nonisolated struct PhotoStorageService {
    nonisolated enum PhotoKind: String, CaseIterable, Equatable, Hashable {
        case before
        case after
        case combined
    }

    nonisolated static let rootDirectoryName = "PairShot"
    nonisolated static let photosDirectoryName = "photos"
    nonisolated static let thumbnailsDirectoryName = "thumbnails"

    let baseDirectory: URL

    nonisolated init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
            return
        }
        do {
            let documents = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.baseDirectory = documents.appendingPathComponent(
                Self.rootDirectoryName,
                isDirectory: true
            )
        } catch {
            preconditionFailure(
                "PhotoStorageService: Documents directory unavailable — \(error)"
            )
        }
    }

    nonisolated var rootDirectory: URL {
        baseDirectory
    }

    nonisolated var photosDirectory: URL {
        baseDirectory.appendingPathComponent(Self.photosDirectoryName, isDirectory: true)
    }

    nonisolated var thumbnailsDirectory: URL {
        baseDirectory.appendingPathComponent(Self.thumbnailsDirectoryName, isDirectory: true)
    }

    nonisolated func photosDirectory(for kind: PhotoKind) -> URL {
        photosDirectory.appendingPathComponent(kind.rawValue, isDirectory: true)
    }

    nonisolated func thumbnailsDirectory(for kind: PhotoKind) -> URL {
        thumbnailsDirectory.appendingPathComponent(kind.rawValue, isDirectory: true)
    }

    nonisolated func saveBeforeJPEG(
        _ jpegData: Data,
        fileName: String
    ) throws -> String {
        try writeJPEG(jpegData, kind: .before, fileName: fileName)
    }

    nonisolated func saveAfterJPEG(
        _ jpegData: Data,
        fileName: String
    ) throws -> String {
        try writeJPEG(jpegData, kind: .after, fileName: fileName)
    }

    nonisolated func saveCombinedJPEG(
        _ jpegData: Data,
        fileName: String
    ) throws -> String {
        try writeJPEG(jpegData, kind: .combined, fileName: fileName)
    }

    nonisolated func saveThumbnailJPEG(
        _ jpegData: Data,
        kind: PhotoKind,
        fileName: String
    ) throws -> String {
        try ensureThumbnailsDirectoryExists(for: kind)
        let dir = thumbnailsDirectory(for: kind)
        let url = dir.appendingPathComponent(fileName)
        try jpegData.write(to: url, options: .atomic)
        return relativeThumbnailPath(kind: kind, fileName: fileName)
    }

    nonisolated func resolveBefore(fileName: String) -> URL? {
        resolve(kind: .before, fileName: fileName)
    }

    nonisolated func resolveAfter(fileName: String) -> URL? {
        resolve(kind: .after, fileName: fileName)
    }

    nonisolated func resolveCombined(fileName: String) -> URL? {
        resolve(kind: .combined, fileName: fileName)
    }

    nonisolated func resolveThumbnail(kind: PhotoKind, fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        return thumbnailsDirectory(for: kind).appendingPathComponent(fileName, isDirectory: false)
    }

    nonisolated func resolve(kind: PhotoKind, fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        return photosDirectory(for: kind).appendingPathComponent(fileName, isDirectory: false)
    }

    nonisolated func deletePhoto(kind: PhotoKind, fileName: String) throws {
        guard let url = resolve(kind: kind, fileName: fileName) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                AppLogger.storage.error(
                    "Storage deletePhoto failed (kind=\(kind.rawValue, privacy: .public)): \(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
        }
    }

    nonisolated func deleteThumbnail(kind: PhotoKind, fileName: String) throws {
        guard let url = resolveThumbnail(kind: kind, fileName: fileName) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    nonisolated func deletePhotosForPair(
        beforeFileName: String?,
        afterFileName: String?,
        combinedFileName: String?
    ) {
        if let name = beforeFileName, !name.isEmpty {
            try? deletePhoto(kind: .before, fileName: name)
            try? deleteThumbnail(kind: .before, fileName: FileNameBuilder.thumbnail(forBaseName: name))
        }
        if let name = afterFileName, !name.isEmpty {
            try? deletePhoto(kind: .after, fileName: name)
            try? deleteThumbnail(kind: .after, fileName: FileNameBuilder.thumbnail(forBaseName: name))
        }
        if let name = combinedFileName, !name.isEmpty {
            try? deletePhoto(kind: .combined, fileName: name)
            try? deleteThumbnail(kind: .combined, fileName: FileNameBuilder.thumbnail(forBaseName: name))
        }
    }

    nonisolated func directorySize() throws -> Int64 {
        try totalAllocatedBytes(under: photosDirectory) + totalAllocatedBytes(under: thumbnailsDirectory)
    }

    nonisolated func photosDirectorySize() throws -> Int64 {
        try totalAllocatedBytes(under: photosDirectory)
    }

    nonisolated func thumbnailsDirectorySize() throws -> Int64 {
        try totalAllocatedBytes(under: thumbnailsDirectory)
    }

    nonisolated func enumerateAllFiles() throws -> [URL] {
        var output: [URL] = []
        for kind in [PhotoKind.before, .after, .combined] {
            try output.append(contentsOf: enumerateFiles(under: photosDirectory(for: kind)))
        }
        return output
    }

    nonisolated func enumerateFiles(kind: PhotoKind) throws -> [URL] {
        try enumerateFiles(under: photosDirectory(for: kind))
    }

    nonisolated func clearAllThumbnails() throws {
        let dir = thumbnailsDirectory
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        try FileManager.default.removeItem(at: dir)
    }

    nonisolated func orphanFiles(referencedFileNames: Set<String>) throws -> [URL] {
        let all = try enumerateAllFiles()
        return all.filter { !referencedFileNames.contains($0.lastPathComponent) }
    }

    nonisolated func deleteOrphanFiles(
        referencedFileNames: Set<String>
    ) throws -> (deletedCount: Int, freedBytes: Int64) {
        let orphans = try orphanFiles(referencedFileNames: referencedFileNames)
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
                AppLogger.storage.error(
                    "Storage orphan delete failed: \(error.localizedDescription, privacy: .public)"
                )
                continue
            }
        }
        AppLogger.storage.info(
            "Storage orphan sweep complete: deleted=\(deletedCount, privacy: .public) freed=\(freedBytes, privacy: .public)"
        )
        return (deletedCount, freedBytes)
    }

    private nonisolated func writeJPEG(
        _ jpegData: Data,
        kind: PhotoKind,
        fileName: String
    ) throws -> String {
        try ensurePhotosDirectoryExists(for: kind)
        let dir = photosDirectory(for: kind)
        let url = dir.appendingPathComponent(fileName)
        do {
            try jpegData.write(to: url, options: .atomic)
        } catch {
            AppLogger.storage.error(
                "Storage writeJPEG failed (kind=\(kind.rawValue, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
        AppLogger.storage.info("Storage saved photo (kind=\(kind.rawValue, privacy: .public))")
        return fileName
    }

    private nonisolated func relativeThumbnailPath(kind: PhotoKind, fileName: String) -> String {
        "\(Self.thumbnailsDirectoryName)/\(kind.rawValue)/\(fileName)"
    }

    private nonisolated func ensurePhotosDirectoryExists(for kind: PhotoKind) throws {
        let dir = photosDirectory(for: kind)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var mutable = dir
        try? Self.includeInBackup(&mutable)
    }

    private nonisolated func ensureThumbnailsDirectoryExists(for kind: PhotoKind) throws {
        let dir = thumbnailsDirectory(for: kind)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var mutable = dir
        try? Self.markExcludedFromBackup(&mutable)
    }

    private nonisolated func totalAllocatedBytes(under root: URL) throws -> Int64 {
        guard FileManager.default.fileExists(atPath: root.path) else { return 0 }
        var total: Int64 = 0
        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true else { continue }
            let bytes = values.totalFileAllocatedSize
                ?? values.fileAllocatedSize
                ?? values.fileSize
                ?? 0
            total += Int64(bytes)
        }
        return total
    }

    private nonisolated func enumerateFiles(under root: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var output: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            if values.isRegularFile == true {
                output.append(url)
            }
        }
        return output
    }

    nonisolated static func markExcludedFromBackup(_ url: inout URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    nonisolated static func includeInBackup(_ url: inout URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        try url.setResourceValues(values)
    }
}

extension PhotoStorageService: PhotoStoring {}
