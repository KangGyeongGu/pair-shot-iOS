import Foundation

struct PhotoStorageService {
    private let fileManager = FileManager.default

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

    func alignedPhotoURL(projectId: UUID, pairId: UUID) throws -> URL {
        try pairDirectoryURL(for: projectId, pairId: pairId)
            .appendingPathComponent("aligned_before.jpg")
    }

    func colorCorrectedPhotoURL(projectId: UUID, pairId: UUID) throws -> URL {
        try pairDirectoryURL(for: projectId, pairId: pairId)
            .appendingPathComponent("corrected_before.jpg")
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

    func deleteProject(projectId: UUID) async {
        guard let projectDir = try? projectDirectoryURL(for: projectId) else { return }
        try? fileManager.removeItem(at: projectDir)
    }

    func deletePair(projectId: UUID, pairId: UUID) async {
        if let pairDir = try? pairDirectoryURL(for: projectId, pairId: pairId) {
            try? fileManager.removeItem(at: pairDir)
        }
        let thumbURLs = [
            try? thumbnailURL(projectId: projectId, pairId: pairId, isBefore: true),
            try? thumbnailURL(projectId: projectId, pairId: pairId, isBefore: false),
        ]
        for url in thumbURLs.compactMap(\.self) {
            try? fileManager.removeItem(at: url)
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
