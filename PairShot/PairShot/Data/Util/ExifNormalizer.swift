import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum ExifNormalizer {
    static let defaultJPEGQuality: CGFloat = 0.95

    static func normalize(_ data: Data, jpegQuality: CGFloat = defaultJPEGQuality) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let normalizedImage = redrawWithUprightOrientation(image)
        guard let normalizedData = encode(normalizedImage, quality: jpegQuality) else {
            return data
        }
        return stampOrientationOne(normalizedData) ?? normalizedData
    }

    static func redrawWithUprightOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func stampOrientationOne(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let metadata: [String: Any] = [
            kCGImagePropertyOrientation as String: 1
        ]
        CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }

    private static func encode(_ image: UIImage, quality: CGFloat) -> Data? {
        image.jpegData(compressionQuality: quality)
    }
}

enum ExifNormalizationTask {
    static func normalize(data: Data, jpegQuality: CGFloat) async -> Data {
        await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                ExifNormalizer.normalize(data, jpegQuality: jpegQuality)
            }
        }.value
    }
}

struct ExifNormalizerAdapter: ExifNormalizing {
    func normalize(_ data: Data, jpegQuality: Double) async -> Data {
        await ExifNormalizationTask.normalize(data: data, jpegQuality: CGFloat(jpegQuality))
    }
}
