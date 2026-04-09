import Foundation

struct PhotoStorageService {
    private let fileManager = FileManager.default

    nonisolated init() {}

    private var documentsURL: URL {
        get throws {
            guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw StorageError.documentsDirectoryUnavailable
            }
            return url
        }
    }

    enum StorageError: Error {
        case documentsDirectoryUnavailable
    }

    func projectDirectoryURL(for projectId: UUID) throws -> URL {
        try documentsURL
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(projectId.uuidString, isDirectory: true)
    }

    func pairDirectoryURL(for projectId: UUID, pairId: UUID) throws -> URL {
        try projectDirectoryURL(for: projectId)
            .appendingPathComponent("pairs", isDirectory: true)
            .appendingPathComponent(pairId.uuidString, isDirectory: true)
    }

    func thumbnailDirectoryURL(for projectId: UUID) throws -> URL {
        try projectDirectoryURL(for: projectId)
            .appendingPathComponent("thumbs", isDirectory: true)
    }

    func photoURL(projectId: UUID, pairId: UUID, isBefore: Bool) throws -> URL {
        let filename = isBefore ? "before.jpg" : "after.jpg"
        return try pairDirectoryURL(for: projectId, pairId: pairId)
            .appendingPathComponent(filename)
    }

    func alignedPhotoRelativePath(projectId: UUID, pairId: UUID) -> String {
        "projects/\(projectId.uuidString)/pairs/\(pairId.uuidString)/aligned_after.jpg"
    }

    func colorCorrectedPhotoRelativePath(projectId: UUID, pairId: UUID) -> String {
        "projects/\(projectId.uuidString)/pairs/\(pairId.uuidString)/corrected_after.jpg"
    }

    func alignedPhotoURL(projectId: UUID, pairId: UUID) throws -> URL {
        try pairDirectoryURL(for: projectId, pairId: pairId)
            .appendingPathComponent("aligned_after.jpg")
    }

    func colorCorrectedPhotoURL(projectId: UUID, pairId: UUID) throws -> URL {
        try pairDirectoryURL(for: projectId, pairId: pairId)
            .appendingPathComponent("corrected_after.jpg")
    }

    func thumbnailURL(projectId: UUID, pairId: UUID, isBefore: Bool) throws -> URL {
        let suffix = isBefore ? "before" : "after"
        return try thumbnailDirectoryURL(for: projectId)
            .appendingPathComponent("\(pairId.uuidString)_\(suffix).jpg")
    }

    func createDirectories(for projectId: UUID, pairId: UUID) throws {
        let pairDir = try pairDirectoryURL(for: projectId, pairId: pairId)
        let thumbDir = try thumbnailDirectoryURL(for: projectId)
        try fileManager.createDirectory(at: pairDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbDir, withIntermediateDirectories: true)
    }

    nonisolated func deleteProject(projectId: UUID) {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let projectDir = docs
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(projectId.uuidString, isDirectory: true)
        try? fm.removeItem(at: projectDir)
    }

    nonisolated func deletePair(projectId: UUID, pairId: UUID) {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let base = docs.appendingPathComponent("projects/\(projectId.uuidString)", isDirectory: true)
        let pairDir = base.appendingPathComponent("pairs/\(pairId.uuidString)", isDirectory: true)
        try? fm.removeItem(at: pairDir)
        let thumbsDir = base.appendingPathComponent("thumbs", isDirectory: true)
        for suffix in ["before", "after"] {
            let thumbURL = thumbsDir.appendingPathComponent("\(pairId.uuidString)_\(suffix).jpg")
            try? fm.removeItem(at: thumbURL)
        }
    }

    func cleanOrphanFiles(existingProjectIds: Set<UUID>) async {
        guard let projectsRoot = try? documentsURL.appendingPathComponent("projects", isDirectory: true),
              let entries = try? fileManager.contentsOfDirectory(
                  at: projectsRoot,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: .skipsHiddenFiles
              )
        else { return }

        for entry in entries {
            guard let id = UUID(uuidString: entry.lastPathComponent),
                  !existingProjectIds.contains(id)
            else { continue }
            try? fileManager.removeItem(at: entry)
        }
    }
}
