import Foundation
import UniformTypeIdentifiers

final nonisolated class TutorialPhotoStore: Sendable {
    enum StoreError: Error, Equatable {
        case directoryUnavailable
        case writeFailed(String)
    }

    static let identifierPrefix = "tutorial://"

    private let directoryURL: URL
    private var fileManager: FileManager {
        .default
    }

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            self.directoryURL = caches.appendingPathComponent("tutorial-photos", isDirectory: true)
        }
    }

    @discardableResult
    func save(data: Data, utType: UTType) async throws -> String {
        try ensureDirectory()
        let fileExtension = Self.fileExtension(for: utType)
        let name = "\(UUID().uuidString).\(fileExtension)"
        let fileURL = directoryURL.appendingPathComponent(name, isDirectory: false)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw StoreError.writeFailed(String(describing: error))
        }
        return Self.identifierPrefix + name
    }

    func loadData(localIdentifier: String) async -> Data? {
        guard let fileURL = fileURL(forIdentifier: localIdentifier) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    func delete(localIdentifiers: [String]) throws {
        for identifier in localIdentifiers {
            guard let fileURL = fileURL(forIdentifier: identifier) else { continue }
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            try fileManager.removeItem(at: fileURL)
        }
    }

    private func ensureDirectory() throws {
        if fileManager.fileExists(atPath: directoryURL.path) { return }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw StoreError.directoryUnavailable
        }
    }

    private func fileURL(forIdentifier identifier: String) -> URL? {
        guard Self.isTutorialIdentifier(identifier) else { return nil }
        let name = String(identifier.dropFirst(Self.identifierPrefix.count))
        guard !name.isEmpty else { return nil }
        return directoryURL.appendingPathComponent(name, isDirectory: false)
    }

    static func isTutorialIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
    }

    private static func fileExtension(for utType: UTType) -> String {
        if let preferred = utType.preferredFilenameExtension { return preferred }
        if utType == .jpeg { return "jpg" }
        if utType == .heic { return "heic" }
        if utType == .png { return "png" }
        return "dat"
    }
}
