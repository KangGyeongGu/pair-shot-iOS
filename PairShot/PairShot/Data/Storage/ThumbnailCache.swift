import Foundation
import OSLog
import UIKit

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    nonisolated static let defaultThumbnailPixelSize: CGFloat = 600

    let underlying: PhotoLibraryThumbnailCache

    init() {
        underlying = PhotoLibraryThumbnailCache.shared
    }

    init(underlying: PhotoLibraryThumbnailCache) {
        self.underlying = underlying
    }

    func cached(
        localIdentifier: String,
        pixelSize: CGFloat = ThumbnailCache.defaultThumbnailPixelSize
    ) -> UIImage? {
        underlying.cached(localIdentifier: localIdentifier, targetSize: CGSize(width: pixelSize, height: pixelSize))
    }

    func image(
        for localIdentifier: String,
        pixelSize: CGFloat = ThumbnailCache.defaultThumbnailPixelSize,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async -> UIImage? {
        await underlying.image(
            for: localIdentifier,
            targetSize: CGSize(width: pixelSize, height: pixelSize),
            progressHandler: progressHandler
        )
    }

    func evict(localIdentifier: String) {
        underlying.evict(localIdentifier: localIdentifier)
    }

    func removeAll() {
        underlying.removeAll()
    }
}
