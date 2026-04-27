import Foundation
import UIKit

nonisolated enum WatermarkedSourceProvider {
    static func resolveURLs(
        entries: [ExportSelection.Entry],
        storage: PhotoStorageService,
        watermark: WatermarkSettings?,
        tempDirectory: URL
    ) -> [URL] {
        var urls: [URL] = []
        for entry in entries {
            guard
                let url = storage.resolve(kind: entry.sourceKind, fileName: entry.sourceFileName),
                FileManager.default.fileExists(atPath: url.path)
            else { continue }
            if let watermark, shouldApply(entry.sourceKind) {
                if let stamped = makeWatermarkedURL(
                    sourceURL: url,
                    fileName: entry.sourceFileName,
                    watermark: watermark,
                    tempDirectory: tempDirectory
                ) {
                    urls.append(stamped)
                } else {
                    urls.append(url)
                }
            } else {
                urls.append(url)
            }
        }
        return urls
    }

    static func resolveDataAndExtension(
        for entry: ExportSelection.Entry,
        storage: PhotoStorageService,
        watermark: WatermarkSettings?
    ) -> (data: Data, isJPEG: Bool)? {
        guard
            let url = storage.resolve(kind: entry.sourceKind, fileName: entry.sourceFileName),
            let raw = try? Data(contentsOf: url)
        else { return nil }
        guard let watermark, shouldApply(entry.sourceKind) else {
            return (raw, url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg")
        }
        guard
            let image = UIImage(data: raw),
            let stamped = WatermarkOverlay.apply(to: image, settings: watermark).jpegData(compressionQuality: 0.95)
        else {
            return (raw, true)
        }
        return (stamped, true)
    }

    private static func shouldApply(_ kind: PhotoStorageService.PhotoKind) -> Bool {
        switch kind {
            case .before, .after: true
            case .combined: false
        }
    }

    private static func makeWatermarkedURL(
        sourceURL: URL,
        fileName: String,
        watermark: WatermarkSettings,
        tempDirectory: URL
    ) -> URL? {
        guard
            let raw = try? Data(contentsOf: sourceURL),
            let image = UIImage(data: raw),
            let jpeg = WatermarkOverlay.apply(to: image, settings: watermark).jpegData(compressionQuality: 0.95)
        else { return nil }
        let folder = tempDirectory.appendingPathComponent("pairshot-wm", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try? FileManager.default.removeItem(at: target)
            }
            try jpeg.write(to: target, options: .atomic)
            return target
        } catch {
            return nil
        }
    }
}
