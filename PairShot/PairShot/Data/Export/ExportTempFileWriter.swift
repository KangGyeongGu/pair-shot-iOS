import Foundation
import UIKit

nonisolated enum ExportTempFileWriter {
    static func write(
        data: Data,
        fileName: String,
        tempDirectory: URL,
    ) -> URL? {
        let folder = tempDirectory.appendingPathComponent("pairshot-share", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try? FileManager.default.removeItem(at: target)
            }
            try data.write(to: target, options: .atomic)
            return target
        } catch {
            return nil
        }
    }

    static func sanitizedName(from relativeName: String) -> String {
        relativeName.replacingOccurrences(of: "/", with: "_")
    }
}
