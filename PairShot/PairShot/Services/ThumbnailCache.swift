import Foundation
import UIKit

/// Memory cache for `PhotoPair` thumbnails. Keys are the relative path stored
/// in `PhotoPair.beforePath` / `.afterPath` / `.combinedPath`; values are
/// downsampled `UIImage`s suitable for a 2-column `LazyVGrid` cell.
///
/// Why a singleton: gallery scroll repeatedly mounts/unmounts the same cells
/// and we need a stable cache across views. NSCache is thread-safe and
/// auto-evicts on memory pressure, so it covers both "fast scroll, no decode
/// stutter" (P4.4 done condition) and "low-memory device" gracefully.
///
/// **Disk caching**: deliberately *not* implemented as a separate sidecar.
/// The original JPEG already lives on disk under
/// `Application Support/photos/<UUID>.jpg`; re-decoding it from there is
/// the disk-cache layer. NSCache (memory) + the source JPEG (disk) is the
/// pattern documented in WWDC18 "Image and Graphics Best Practices" — adding
/// a second JPEG-of-thumbnail file just for warmups would double storage with
/// minimal speed gain on iPhone-class flash.
final class ThumbnailCache: @unchecked Sendable {
    /// Shared instance. Concrete `NSCache` is internally thread-safe.
    static let shared = ThumbnailCache()

    /// Approximate target size (points) for a 2-column gallery cell.
    /// 600 px on the long edge handles 3x retina (200 pt × 3) without aliasing.
    static let defaultThumbnailPixelSize: CGFloat = 600

    private let cache: NSCache<NSString, UIImage>

    /// `countLimit` and `totalCostLimit` are loose; NSCache evicts under
    /// `UIApplication.didReceiveMemoryWarning` automatically. We set
    /// generous defaults so casual 200-pair galleries never re-decode.
    init(countLimit: Int = 256, totalCostLimit: Int = 64 * 1024 * 1024) {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        self.cache = cache
    }

    // MARK: - Public

    /// Returns a cached thumbnail for `relativePath` if present, else `nil`.
    /// Pure read — does not trigger a decode.
    func cached(forRelativePath relativePath: String) -> UIImage? {
        guard !relativePath.isEmpty else { return nil }
        return cache.object(forKey: relativePath as NSString)
    }

    /// Loads (or returns cached) thumbnail for `relativePath`. Synchronous —
    /// callers that need this off the main thread should call from a
    /// `Task.detached`.
    ///
    /// - Parameters:
    ///   - relativePath: the value stored in `PhotoPair.beforePath`.
    ///   - storage: resolves the relative path to an absolute file URL.
    ///   - pixelSize: long-edge target in pixels. Default = 600.
    /// - Returns: the decoded `UIImage`, or `nil` if the file is missing
    ///   / unreadable.
    @discardableResult
    func loadThumbnail(
        forRelativePath relativePath: String,
        storage: PhotoStorageService,
        pixelSize: CGFloat = ThumbnailCache.defaultThumbnailPixelSize
    ) -> UIImage? {
        guard !relativePath.isEmpty else { return nil }
        let key = relativePath as NSString
        if let hit = cache.object(forKey: key) {
            return hit
        }
        guard let url = storage.resolve(relativePath: relativePath) else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let image = Self.downsample(at: url, pixelSize: pixelSize) else {
            return nil
        }
        let cost = Self.estimatedByteCost(image)
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }

    /// Drop a single entry — used by the deletion flow so a freshly-deleted
    /// pair's thumbnail does not linger in memory.
    func evict(relativePath: String) {
        guard !relativePath.isEmpty else { return }
        cache.removeObject(forKey: relativePath as NSString)
    }

    /// Wipe the whole cache. Used by tests.
    func removeAll() {
        cache.removeAllObjects()
    }

    // MARK: - Internals (exposed for tests)

    /// Downsample with `ImageIO`. Avoids decoding the full-resolution image
    /// into a `UIImage` and then drawing it down — that's the standard cause
    /// of jank in image grids.
    static func downsample(at url: URL, pixelSize: CGFloat) -> UIImage? {
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

    /// Rough byte cost = w * h * 4 (RGBA). Used as NSCache `cost` so the
    /// `totalCostLimit` reflects real memory pressure rather than raw count.
    static func estimatedByteCost(_ image: UIImage) -> Int {
        let scale = image.scale
        let w = Int(image.size.width * scale)
        let h = Int(image.size.height * scale)
        return max(0, w * h * 4)
    }
}
