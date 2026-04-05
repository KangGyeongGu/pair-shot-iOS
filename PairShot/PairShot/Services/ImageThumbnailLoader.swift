import CoreGraphics
import Foundation
import ImageIO
import UIKit

nonisolated enum ImageThumbnailLoader {
    static func load(url: URL, maxPixelSize: Int = 1200) -> CGImage? {
        guard url.isFileURL,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func loadUIImage(url: URL, maxPixelSize: Int = 1600) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = load(url: url, maxPixelSize: maxPixelSize) else { return nil }
            return UIImage(cgImage: cgImage)
        }.value
    }
}
