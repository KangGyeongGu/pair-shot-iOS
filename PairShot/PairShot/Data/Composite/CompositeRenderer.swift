import CoreLocation
import Foundation
import ImageIO
import MobileCoreServices
import SwiftData
import UIKit
import UniformTypeIdentifiers

// swiftlint:disable switch_case_alignment vertical_whitespace_between_cases

nonisolated enum CompositeRenderer {
    nonisolated enum RenderError: Error, Equatable {
        case beforeImageMissing
        case afterImageMissing
        case afterPathNotSet
        case encodeFailed
        case persistFailed
    }

    struct EncodeRequest {
        let beforeFileName: String
        let afterFileName: String
        let options: CompositeOptions
        let storage: PhotoStorageService
        let now: Date
        let latitude: Double?
        let longitude: Double?
    }

    struct PersistRequest {
        let jpeg: Data
        let pair: PhotoPair
        let previousCombined: String?
        let sequenceNumber: Int
        let fileNamePrefix: String
        let now: Date
        let storage: PhotoStorageService
        let context: ModelContext
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
        let pairLatitude = pair.latitude
        let pairLongitude = pair.longitude
        let sequenceNumber = FileNameBuilder.extractSequenceNumber(from: beforeFileName) ?? 1

        let request = EncodeRequest(
            beforeFileName: beforeFileName,
            afterFileName: afterFileName,
            options: options,
            storage: storage,
            now: now,
            latitude: pairLatitude,
            longitude: pairLongitude
        )
        let jpeg = try await encodeComposite(request)

        return try persist(PersistRequest(
            jpeg: jpeg,
            pair: pair,
            previousCombined: previousCombined,
            sequenceNumber: sequenceNumber,
            fileNamePrefix: fileNamePrefix,
            now: now,
            storage: storage,
            context: context
        ))
    }

    nonisolated static func renderComposite(
        before: UIImage,
        after: UIImage,
        layout: CompositeLayout,
        combineSettings: CombineSettings? = nil
    ) -> UIImage {
        let borderPx = CompositeLabelDrawer.resolveBorderPx(combineSettings)
        let frames = composeFrames(
            beforeSize: before.size,
            afterSize: after.size,
            layout: layout,
            borderPx: borderPx
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: frames.canvas, format: format)
        return renderer.image { context in
            CompositeLabelDrawer.paintCanvasBackground(
                context: context,
                canvas: frames.canvas,
                combineSettings: combineSettings
            )
            before.draw(in: frames.beforeRect)
            after.draw(in: frames.afterRect)
            CompositeLabelDrawer.drawIfEnabled(
                context: context,
                combineSettings: combineSettings,
                beforeRect: frames.beforeRect,
                afterRect: frames.afterRect
            )
        }
    }

    nonisolated static func composeFrames(
        beforeSize: CGSize,
        afterSize: CGSize,
        layout: CompositeLayout,
        borderPx: CGFloat = 0
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        let beforeWidth = max(beforeSize.width, 1)
        let beforeHeight = max(beforeSize.height, 1)
        let afterWidth = max(afterSize.width, 1)
        let afterHeight = max(afterSize.height, 1)
        let border = max(borderPx, 0)
        switch layout {
            case .horizontal:
                return horizontalFrames(
                    beforeWidth: beforeWidth,
                    beforeHeight: beforeHeight,
                    afterWidth: afterWidth,
                    afterHeight: afterHeight,
                    border: border
                )
            case .vertical:
                return verticalFrames(
                    beforeWidth: beforeWidth,
                    beforeHeight: beforeHeight,
                    afterWidth: afterWidth,
                    afterHeight: afterHeight,
                    border: border
                )
        }
    }

    private static func horizontalFrames(
        beforeWidth: CGFloat,
        beforeHeight: CGFloat,
        afterWidth: CGFloat,
        afterHeight: CGFloat,
        border: CGFloat
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        let commonHeight = min(beforeHeight, afterHeight)
        let scaledBeforeWidth = beforeWidth * (commonHeight / beforeHeight)
        let scaledAfterWidth = afterWidth * (commonHeight / afterHeight)
        let canvas = CGSize(
            width: scaledBeforeWidth + scaledAfterWidth + border * 3,
            height: commonHeight + border * 2
        )
        let beforeRect = CGRect(
            x: border,
            y: border,
            width: scaledBeforeWidth,
            height: commonHeight
        )
        let afterRect = CGRect(
            x: border + scaledBeforeWidth + border,
            y: border,
            width: scaledAfterWidth,
            height: commonHeight
        )
        return (canvas, beforeRect, afterRect)
    }

    private static func verticalFrames(
        beforeWidth: CGFloat,
        beforeHeight: CGFloat,
        afterWidth: CGFloat,
        afterHeight: CGFloat,
        border: CGFloat
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        let commonWidth = min(beforeWidth, afterWidth)
        let scaledBeforeHeight = beforeHeight * (commonWidth / beforeWidth)
        let scaledAfterHeight = afterHeight * (commonWidth / afterWidth)
        let canvas = CGSize(
            width: commonWidth + border * 2,
            height: scaledBeforeHeight + scaledAfterHeight + border * 3
        )
        let beforeRect = CGRect(
            x: border,
            y: border,
            width: commonWidth,
            height: scaledBeforeHeight
        )
        let afterRect = CGRect(
            x: border,
            y: border + scaledBeforeHeight + border,
            width: commonWidth,
            height: scaledAfterHeight
        )
        return (canvas, beforeRect, afterRect)
    }

    private static func encodeComposite(_ request: EncodeRequest) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try autoreleasepool {
                guard let beforeImage = loadImage(
                    kind: .before,
                    fileName: request.beforeFileName,
                    storage: request.storage
                ) else {
                    throw RenderError.beforeImageMissing
                }
                guard let afterImage = loadImage(
                    kind: .after,
                    fileName: request.afterFileName,
                    storage: request.storage
                ) else {
                    throw RenderError.afterImageMissing
                }
                let stampedBefore: UIImage
                let stampedAfter: UIImage
                if request.options.watermarkEnabled, let watermark = request.options.watermark {
                    stampedBefore = WatermarkOverlay.apply(to: beforeImage, settings: watermark)
                    stampedAfter = WatermarkOverlay.apply(to: afterImage, settings: watermark)
                } else {
                    stampedBefore = beforeImage
                    stampedAfter = afterImage
                }
                let composite = renderComposite(
                    before: stampedBefore,
                    after: stampedAfter,
                    layout: request.options.layout,
                    combineSettings: request.options.combineSettings
                )
                guard let baseJPEG = composite.jpegData(
                    compressionQuality: request.options.jpegQuality
                ) else {
                    throw RenderError.encodeFailed
                }
                return ExifEmbedder.embed(
                    into: baseJPEG,
                    capturedAt: request.now,
                    latitude: request.latitude,
                    longitude: request.longitude
                ) ?? baseJPEG
            }
        }.value
    }

    @MainActor
    private static func persist(_ request: PersistRequest) throws -> String {
        if let previous = request.previousCombined, !previous.isEmpty {
            try? request.storage.deletePhoto(kind: .combined, fileName: previous)
            ThumbnailCache.shared.evict(combinedFileName: previous)
        }
        let combinedFileName = FileNameBuilder.combined(
            prefix: request.fileNamePrefix,
            timestamp: request.now,
            sequenceNumber: request.sequenceNumber
        )
        do {
            _ = try request.storage.saveCombinedJPEG(request.jpeg, fileName: combinedFileName)
        } catch {
            throw RenderError.persistFailed
        }
        request.pair.combinedFileName = combinedFileName
        request.pair.updatedAt = request.now
        for album in request.pair.albums {
            album.updatedAt = request.now
        }
        do {
            try request.context.save()
        } catch {
            throw RenderError.persistFailed
        }
        return combinedFileName
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

// swiftlint:enable switch_case_alignment vertical_whitespace_between_cases

nonisolated enum ExifEmbedder {
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
