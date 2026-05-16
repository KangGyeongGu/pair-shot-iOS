import CoreLocation
import Foundation
import ImageIO
import MobileCoreServices
import SwiftData
import UIKit
import UniformTypeIdentifiers

nonisolated enum CompositeRenderer {
    nonisolated enum RenderError: Error, Equatable {
        case beforeImageMissing
        case afterImageMissing
        case afterPathNotSet
        case encodeFailed
    }

    static let referenceImageWidth: CGFloat = 1024
    static let exifDateFormat = "yyyy:MM:dd HH:mm:ss"

    @MainActor
    static func makeComposite(
        for pair: PhotoPair,
        photoLibrary: PhotoLibraryService,
        options: CompositeOptions = .default,
        now: Date = .now,
    ) async throws -> Data {
        guard
            let beforeId = pair.beforePhotoLocalIdentifier, !beforeId.isEmpty
        else {
            throw RenderError.beforeImageMissing
        }
        guard
            let afterId = pair.afterPhotoLocalIdentifier, !afterId.isEmpty
        else {
            throw RenderError.afterPathNotSet
        }

        async let beforeData = photoLibrary.requestImageData(localIdentifier: beforeId)
        async let afterData = photoLibrary.requestImageData(localIdentifier: afterId)
        guard let bData = await beforeData else {
            throw RenderError.beforeImageMissing
        }
        guard let aData = await afterData else {
            throw RenderError.afterImageMissing
        }

        let pairLatitude = options.includeGPS ? pair.latitude : nil
        let pairLongitude = options.includeGPS ? pair.longitude : nil

        return try await Task.detached(priority: .userInitiated) {
            try autoreleasepool {
                try composeJPEG(
                    beforeData: bData,
                    afterData: aData,
                    options: options,
                    capturedAt: now,
                    latitude: pairLatitude,
                    longitude: pairLongitude,
                )
            }
        }.value
    }

    nonisolated static func composeJPEG(
        beforeData: Data,
        afterData: Data,
        options: CompositeOptions,
        capturedAt: Date,
        latitude: Double?,
        longitude: Double?,
    ) throws -> Data {
        guard let beforeImage = CompositeImageDecoder.decode(data: beforeData) else {
            throw RenderError.beforeImageMissing
        }
        guard let afterImage = CompositeImageDecoder.decode(data: afterData) else {
            throw RenderError.afterImageMissing
        }
        let composite = renderComposite(
            before: beforeImage,
            after: afterImage,
            layout: options.layout,
            combineSettings: options.combineSettings,
            watermark: options.watermarkEnabled ? options.watermark : nil,
        )
        guard let cgImage = composite.cgImage else {
            throw RenderError.encodeFailed
        }
        guard let encoded = CompositeJPEGEncoder.encode(
            cgImage: cgImage,
            quality: options.jpegQuality,
            capturedAt: capturedAt,
            latitude: latitude,
            longitude: longitude,
        ) else {
            throw RenderError.encodeFailed
        }
        return encoded
    }

    @MainActor
    static func renderSingle(
        image: UIImage,
        combineSettings: CombineSettings?,
        isBefore: Bool,
        watermark: WatermarkSettings?,
        jpegQuality: CGFloat,
    ) -> Data? {
        let composed = renderSingleComposite(
            image: image,
            combineSettings: combineSettings,
            isBefore: isBefore,
            watermark: watermark,
        )
        return composed.jpegData(compressionQuality: jpegQuality)
    }

    nonisolated static func renderSingleComposite(
        image: UIImage,
        combineSettings: CombineSettings?,
        isBefore: Bool,
        watermark: WatermarkSettings? = nil,
    ) -> UIImage {
        let imageWidth = max(image.size.width, 1)
        let scaleFactor = imageWidth / referenceImageWidth
        let baseBorderPx = CompositeLabelDrawer.resolveBorderPx(combineSettings)
        let borderPx = baseBorderPx * scaleFactor
        let canvasSize = CGSize(
            width: image.size.width + borderPx * 2,
            height: image.size.height + borderPx * 2,
        )
        let imageRect = CGRect(
            x: borderPx,
            y: borderPx,
            width: image.size.width,
            height: image.size.height,
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            CompositeLabelDrawer.paintCanvasBackground(
                context: context,
                canvas: canvasSize,
                combineSettings: combineSettings,
            )
            image.draw(in: imageRect)
            if let watermark {
                WatermarkOverlay.draw(in: imageRect, settings: watermark)
            }
            CompositeLabelDrawer.drawSingleIfEnabled(
                context: context,
                combineSettings: combineSettings,
                imageRect: imageRect,
                isBefore: isBefore,
                scaleFactor: scaleFactor,
            )
        }
    }

    nonisolated static func renderComposite(
        before: UIImage,
        after: UIImage,
        layout: CompositeLayout,
        combineSettings: CombineSettings? = nil,
        watermark: WatermarkSettings? = nil,
    ) -> UIImage {
        let imageMaxWidth = max(before.size.width, after.size.width, 1)
        let scaleFactor = imageMaxWidth / referenceImageWidth
        let baseBorderPx = CompositeLabelDrawer.resolveBorderPx(combineSettings)
        let borderPx = baseBorderPx * scaleFactor
        let frames = composeFrames(
            beforeSize: before.size,
            afterSize: after.size,
            layout: layout,
            borderPx: borderPx,
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: frames.canvas, format: format)
        return renderer.image { context in
            CompositeLabelDrawer.paintCanvasBackground(
                context: context,
                canvas: frames.canvas,
                combineSettings: combineSettings,
            )
            before.draw(in: frames.beforeRect)
            after.draw(in: frames.afterRect)
            if let watermark {
                WatermarkOverlay.draw(in: frames.beforeRect, settings: watermark)
                WatermarkOverlay.draw(in: frames.afterRect, settings: watermark)
            }
            CompositeLabelDrawer.drawIfEnabled(
                context: context,
                combineSettings: combineSettings,
                beforeRect: frames.beforeRect,
                afterRect: frames.afterRect,
                scaleFactor: scaleFactor,
            )
        }
    }

    nonisolated static func composeFrames(
        beforeSize: CGSize,
        afterSize: CGSize,
        layout: CompositeLayout,
        borderPx: CGFloat = 0,
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        let beforeWidth = max(beforeSize.width, 1)
        let beforeHeight = max(beforeSize.height, 1)
        let afterWidth = max(afterSize.width, 1)
        let afterHeight = max(afterSize.height, 1)
        let border = max(borderPx, 0)
        switch layout {
            case .horizontal:
                return CompositeFrameMath.horizontal(
                    beforeWidth: beforeWidth,
                    beforeHeight: beforeHeight,
                    afterWidth: afterWidth,
                    afterHeight: afterHeight,
                    border: border,
                )

            case .vertical:
                return CompositeFrameMath.vertical(
                    beforeWidth: beforeWidth,
                    beforeHeight: beforeHeight,
                    afterWidth: afterWidth,
                    afterHeight: afterHeight,
                    border: border,
                )
        }
    }
}

private nonisolated enum CompositeImageDecoder {
    static func decode(data: Data) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, sourceOptions as CFDictionary) else {
            return nil
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        let rawOrientation = properties?[kCGImagePropertyOrientation as String] as? UInt32 ?? 1
        let cgOrientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up
        return UIImage(cgImage: cgImage, scale: 1, orientation: uiOrientation(from: cgOrientation))
    }

    static func uiOrientation(from cgOrientation: CGImagePropertyOrientation) -> UIImage.Orientation {
        switch cgOrientation {
            case .up: .up
            case .upMirrored: .upMirrored
            case .down: .down
            case .downMirrored: .downMirrored
            case .leftMirrored: .leftMirrored
            case .right: .right
            case .rightMirrored: .rightMirrored
            case .left: .left
        }
    }
}

private nonisolated enum CompositeJPEGEncoder {
    static func encode(
        cgImage: CGImage,
        quality: CGFloat,
        capturedAt: Date,
        latitude: Double?,
        longitude: Double?,
    ) -> Data? {
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.jpeg.identifier as CFString,
            1,
            nil,
        ) else {
            return nil
        }
        let stamp = exifTimestamp(from: capturedAt)
        var properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: stamp,
                kCGImagePropertyExifDateTimeDigitized: stamp,
            ] as [CFString: Any],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFDateTime: stamp,
            ] as [CFString: Any],
        ]
        if let latitude, let longitude {
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: abs(latitude),
                kCGImagePropertyGPSLatitudeRef: latitude >= 0 ? "N" : "S",
                kCGImagePropertyGPSLongitude: abs(longitude),
                kCGImagePropertyGPSLongitudeRef: longitude >= 0 ? "E" : "W",
            ] as [CFString: Any]
        }
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }

    private static func exifTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = CompositeRenderer.exifDateFormat
        return formatter.string(from: date)
    }
}

private nonisolated enum CompositeFrameMath {
    static func horizontal(
        beforeWidth: CGFloat,
        beforeHeight: CGFloat,
        afterWidth: CGFloat,
        afterHeight: CGFloat,
        border: CGFloat,
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        let commonHeight = min(beforeHeight, afterHeight)
        let scaledBeforeWidth = beforeWidth * (commonHeight / beforeHeight)
        let scaledAfterWidth = afterWidth * (commonHeight / afterHeight)
        let canvas = CGSize(
            width: scaledBeforeWidth + scaledAfterWidth + border * 3,
            height: commonHeight + border * 2,
        )
        let beforeRect = CGRect(
            x: border,
            y: border,
            width: scaledBeforeWidth,
            height: commonHeight,
        )
        let afterRect = CGRect(
            x: border + scaledBeforeWidth + border,
            y: border,
            width: scaledAfterWidth,
            height: commonHeight,
        )
        return (canvas, beforeRect, afterRect)
    }

    static func vertical(
        beforeWidth: CGFloat,
        beforeHeight: CGFloat,
        afterWidth: CGFloat,
        afterHeight: CGFloat,
        border: CGFloat,
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        let commonWidth = min(beforeWidth, afterWidth)
        let scaledBeforeHeight = beforeHeight * (commonWidth / beforeWidth)
        let scaledAfterHeight = afterHeight * (commonWidth / afterWidth)
        let canvas = CGSize(
            width: commonWidth + border * 2,
            height: scaledBeforeHeight + scaledAfterHeight + border * 3,
        )
        let beforeRect = CGRect(
            x: border,
            y: border,
            width: commonWidth,
            height: scaledBeforeHeight,
        )
        let afterRect = CGRect(
            x: border,
            y: border + scaledBeforeHeight + border,
            width: commonWidth,
            height: scaledAfterHeight,
        )
        return (canvas, beforeRect, afterRect)
    }
}
