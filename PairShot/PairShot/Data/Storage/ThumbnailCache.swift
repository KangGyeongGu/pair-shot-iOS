import Foundation
import OSLog
import UIKit

final nonisolated class ThumbnailCache: @unchecked Sendable {
    nonisolated static let shared = ThumbnailCache()

    nonisolated static let defaultThumbnailPixelSize: CGFloat = 600

    private let cache: NSCache<NSString, UIImage>

    nonisolated init(countLimit: Int = 256, totalCostLimit: Int = 64 * 1024 * 1024) {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        self.cache = cache
    }

    nonisolated func cached(kind: PhotoStorageService.PhotoKind, fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        return cache.object(forKey: cacheKey(kind: kind, fileName: fileName))
    }

    @discardableResult
    nonisolated func loadThumbnail(
        kind: PhotoStorageService.PhotoKind,
        fileName: String,
        storage: PhotoStorageService,
        pixelSize: CGFloat = ThumbnailCache.defaultThumbnailPixelSize
    ) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        let key = cacheKey(kind: kind, fileName: fileName)
        if let hit = cache.object(forKey: key) {
            return hit
        }
        let thumbnailFileName = FileNameBuilder.thumbnail(forBaseName: fileName)
        if let thumbnailURL = storage.resolveThumbnail(kind: kind, fileName: thumbnailFileName),
           FileManager.default.fileExists(atPath: thumbnailURL.path),
           let image = UIImage(contentsOfFile: thumbnailURL.path)
        {
            cache.setObject(image, forKey: key, cost: Self.estimatedByteCost(image))
            return image
        }
        guard let url = storage.resolve(kind: kind, fileName: fileName) else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let image = Self.downsample(at: url, pixelSize: pixelSize) else {
            AppLogger.storage.error("Thumbnail downsample failed (kind=\(kind.rawValue, privacy: .public))")
            return nil
        }
        let cost = Self.estimatedByteCost(image)
        cache.setObject(image, forKey: key, cost: cost)
        if let data = image.jpegData(compressionQuality: 0.7) {
            do {
                _ = try storage.saveThumbnailJPEG(data, kind: kind, fileName: thumbnailFileName)
            } catch {
                AppLogger.storage.error(
                    "Thumbnail persist failed (kind=\(kind.rawValue, privacy: .public)): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        return image
    }

    nonisolated func evict(kind: PhotoStorageService.PhotoKind, fileName: String) {
        guard !fileName.isEmpty else { return }
        cache.removeObject(forKey: cacheKey(kind: kind, fileName: fileName))
    }

    nonisolated func evict(beforeFileName: String) {
        evict(kind: .before, fileName: beforeFileName)
    }

    nonisolated func evict(afterFileName: String) {
        evict(kind: .after, fileName: afterFileName)
    }

    nonisolated func evict(combinedFileName: String) {
        evict(kind: .combined, fileName: combinedFileName)
    }

    nonisolated func removeAll() {
        cache.removeAllObjects()
    }

    private nonisolated func cacheKey(kind: PhotoStorageService.PhotoKind, fileName: String) -> NSString {
        "\(kind.rawValue)/\(fileName)" as NSString
    }

    nonisolated static func downsample(at url: URL, pixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
            return nil
        }
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, downsampleOptions as CFDictionary
        ) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    nonisolated static func estimatedByteCost(_ image: UIImage) -> Int {
        let scale = image.scale
        let w = Int(image.size.width * scale)
        let h = Int(image.size.height * scale)
        return max(0, w * h * 4)
    }
}
