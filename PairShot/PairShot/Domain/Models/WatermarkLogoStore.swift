import Foundation

final nonisolated class WatermarkLogoStore: @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager

    init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default,
    ) {
        self.fileManager = fileManager
        if let baseDirectory {
            directory = baseDirectory
        } else {
            let base = (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true,
            )) ?? fileManager.temporaryDirectory
            directory = base.appendingPathComponent("Watermark", isDirectory: true)
        }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(_ data: Data) throws -> String {
        let ref = UUID().uuidString
        try data.write(to: url(forRef: ref), options: .atomic)
        return ref
    }

    func load(ref: String) -> Data? {
        try? Data(contentsOf: url(forRef: ref))
    }

    func delete(ref: String) {
        try? fileManager.removeItem(at: url(forRef: ref))
    }

    private func url(forRef ref: String) -> URL {
        directory.appendingPathComponent("\(ref).dat", isDirectory: false)
    }
}
