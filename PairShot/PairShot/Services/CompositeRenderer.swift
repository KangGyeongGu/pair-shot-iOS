import CoreLocation
import Foundation
import ImageIO
import MobileCoreServices
import SwiftData
import UIKit
import UniformTypeIdentifiers

enum CompositeRenderer {
    enum RenderError: Error, Equatable {
        case beforeImageMissing
        case afterImageMissing
        case afterPathNotSet
        case encodeFailed
        case persistFailed
    }

    @MainActor
    @discardableResult
    static func makeComposite(
        for pair: PhotoPair,
        options: CompositeOptions = .default,
        storage: PhotoStorageService = PhotoStorageService(),
        fileNamePrefix: String = "",
        in context: ModelContext,
        now: Date = .now
    ) async throws -> String {
        guard let afterFileName = pair.afterFileName, !afterFileName.isEmpty else {
            throw RenderError.afterPathNotSet
        }
        let beforeFileName = pair.beforeFileName
        let previousCombined = pair.combinedFileName
        let pairId = pair.id
        let pairLatitude = pair.latitude
        let pairLongitude = pair.longitude

        let jpeg: Data = try await Task.detached(priority: .userInitiated) {
            try autoreleasepool {
                guard let beforeImage = loadImage(kind: .before, fileName: beforeFileName, storage: storage) else {
                    throw RenderError.beforeImageMissing
                }
                guard let afterImage = loadImage(kind: .after, fileName: afterFileName, storage: storage) else {
                    throw RenderError.afterImageMissing
                }
                var composite = renderComposite(
                    before: beforeImage,
                    after: afterImage,
                    layout: options.layout
                )
                if options.watermarkEnabled {
                    composite = WatermarkOverlay.apply(to: composite, date: now)
                }
                guard let baseJPEG = composite.jpegData(
                    compressionQuality: options.jpegQuality
                ) else {
                    throw RenderError.encodeFailed
                }
                return ExifEmbedder.embed(
                    into: baseJPEG,
                    capturedAt: now,
                    latitude: pairLatitude,
                    longitude: pairLongitude
                ) ?? baseJPEG
            }
        }.value

        if let previousCombined, !previousCombined.isEmpty {
            try? storage.deletePhoto(kind: .combined, fileName: previousCombined)
            ThumbnailCache.shared.evict(combinedFileName: previousCombined)
        }

        let combinedFileName = FileNameBuilder.combined(
            prefix: fileNamePrefix,
            timestamp: now,
            pairId: pairId
        )
        do {
            _ = try storage.saveCombinedJPEG(jpeg, fileName: combinedFileName)
        } catch {
            throw RenderError.persistFailed
        }
        pair.combinedFileName = combinedFileName
        pair.updatedAt = now
        for album in pair.albums {
            album.updatedAt = now
        }
        do {
            try context.save()
        } catch {
            throw RenderError.persistFailed
        }
        return combinedFileName
    }

    static func renderComposite(
        before: UIImage,
        after: UIImage,
        layout: CompositeLayout
    ) -> UIImage {
        let frames = composeFrames(
            beforeSize: before.size,
            afterSize: after.size,
            layout: layout
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: frames.canvas, format: format)
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: frames.canvas))
            before.draw(in: frames.beforeRect)
            after.draw(in: frames.afterRect)
        }
    }

    static func composeFrames(
        beforeSize: CGSize,
        afterSize: CGSize,
        layout: CompositeLayout
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        let beforeWidth = max(beforeSize.width, 1)
        let beforeHeight = max(beforeSize.height, 1)
        let afterWidth = max(afterSize.width, 1)
        let afterHeight = max(afterSize.height, 1)

        switch layout {
            case .horizontal:
                let commonHeight = min(beforeHeight, afterHeight)
                let scaledBeforeWidth = beforeWidth * (commonHeight / beforeHeight)
                let scaledAfterWidth = afterWidth * (commonHeight / afterHeight)
                let canvas = CGSize(
                    width: scaledBeforeWidth + scaledAfterWidth,
                    height: commonHeight
                )
                let beforeRect = CGRect(x: 0, y: 0, width: scaledBeforeWidth, height: commonHeight)
                let afterRect = CGRect(
                    x: scaledBeforeWidth, y: 0,
                    width: scaledAfterWidth, height: commonHeight
                )
                return (canvas, beforeRect, afterRect)

            case .vertical:
                let commonWidth = min(beforeWidth, afterWidth)
                let scaledBeforeHeight = beforeHeight * (commonWidth / beforeWidth)
                let scaledAfterHeight = afterHeight * (commonWidth / afterWidth)
                let canvas = CGSize(
                    width: commonWidth,
                    height: scaledBeforeHeight + scaledAfterHeight
                )
                let beforeRect = CGRect(x: 0, y: 0, width: commonWidth, height: scaledBeforeHeight)
                let afterRect = CGRect(
                    x: 0, y: scaledBeforeHeight,
                    width: commonWidth, height: scaledAfterHeight
                )
                return (canvas, beforeRect, afterRect)
        }
    }

    private static func loadImage(
        kind: PhotoStorageService.PhotoKind,
        fileName: String,
        storage: PhotoStorageService
    ) -> UIImage? {
        guard let url = storage.resolve(kind: kind, fileName: fileName) else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

enum ExifEmbedder {
    static let exifDateFormat = "yyyy:MM:dd HH:mm:ss"

    static func embed(
        into jpeg: Data,
        capturedAt: Date,
        latitude: Double?,
        longitude: Double?
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil) else {
            return nil
        }
        guard CGImageSourceGetType(source) != nil else { return nil }
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        let metadata = makeMetadata(
            capturedAt: capturedAt,
            latitude: latitude,
            longitude: longitude
        )
        CGImageDestinationAddImageFromSource(
            destination,
            source,
            0,
            metadata as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }

    static func makeMetadata(
        capturedAt: Date,
        latitude: Double?,
        longitude: Double?
    ) -> [String: Any] {
        var top: [String: Any] = [:]

        var exif: [String: Any] = [:]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = exifDateFormat
        let stamp = formatter.string(from: capturedAt)
        exif[kCGImagePropertyExifDateTimeOriginal as String] = stamp
        exif[kCGImagePropertyExifDateTimeDigitized as String] = stamp
        top[kCGImagePropertyExifDictionary as String] = exif

        if let lat = latitude, let lon = longitude {
            var gps: [String: Any] = [:]
            gps[kCGImagePropertyGPSLatitude as String] = abs(lat)
            gps[kCGImagePropertyGPSLatitudeRef as String] = lat >= 0 ? "N" : "S"
            gps[kCGImagePropertyGPSLongitude as String] = abs(lon)
            gps[kCGImagePropertyGPSLongitudeRef as String] = lon >= 0 ? "E" : "W"
            top[kCGImagePropertyGPSDictionary as String] = gps
        }
        return top
    }
}
