import Foundation
import ImageIO
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
        options: CompositeOptions,
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
                try composeImage(
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

    nonisolated static func composeImage(
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
        guard let encoded = CompositeImageEncoder.encode(
            cgImage: cgImage,
            utType: options.utType,
            quality: options.compressionQuality,
            capturedAt: capturedAt,
            latitude: latitude,
            longitude: longitude,
        ) else {
            throw RenderError.encodeFailed
        }
        return encoded
    }

    nonisolated static func renderSingleComposite(
        image: UIImage,
        combineSettings: CombineSettings?,
        isBefore: Bool,
        watermark: WatermarkSettings? = nil,
    ) -> UIImage {
        let imageWidth = max(image.size.width, 1)
        let scaleFactor = imageWidth / referenceImageWidth
        let baseBorderPx = CGFloat(CompositeLabelDrawer.resolveBorderPx(combineSettings)) * scaleFactor
        var edges = EdgeBorders.uniform(baseBorderPx)

        if
            let settings = combineSettings,
            settings.label.isEnabled,
            settings.labelPlacement == .border
        {
            let position = isBefore ? settings.beforeBorderPosition : settings.afterBorderPosition
            let stripPx = CompositeLabelDrawer.labelStripPx(
                textSizePercent: settings.label.textSizePercent,
                paneHeight: image.size.height,
            )
            switch position.vertical {
                case .top:
                    edges.top = max(edges.top, stripPx)

                case .bottom:
                    edges.bottom = max(edges.bottom, stripPx)
            }
        }

        let canvasSize = CGSize(
            width: edges.left + image.size.width + edges.right,
            height: edges.top + image.size.height + edges.bottom,
        )
        let imageRect = CGRect(
            x: edges.left,
            y: edges.top,
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
            if
                let settings = combineSettings,
                settings.labelPlacement == .border,
                settings.label.isEnabled
            {
                CompositeLabelDrawer.drawSingleBorderEdgeLabel(
                    context: context,
                    combineSettings: settings,
                    canvas: canvasSize,
                    edges: edges,
                    imageRect: imageRect,
                    isBefore: isBefore,
                )
            } else {
                CompositeLabelDrawer.drawSingleIfEnabled(
                    context: context,
                    combineSettings: combineSettings,
                    imageRect: imageRect,
                    isBefore: isBefore,
                    scaleFactor: scaleFactor,
                )
            }
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
        let paneSizes = CompositeFrameMath.paneScaledSizes(
            beforeSize: before.size,
            afterSize: after.size,
            layout: layout,
        )
        let edges = EdgeBorders.compute(
            paneSizes: paneSizes,
            layout: layout,
            settings: combineSettings,
            scaleFactor: scaleFactor,
        )
        let frames = composeFrames(
            paneSizes: paneSizes,
            layout: layout,
            borders: edges,
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
            if
                let settings = combineSettings,
                settings.labelPlacement == .border,
                settings.label.isEnabled
            {
                CompositeLabelDrawer.drawBorderEdgeLabels(
                    context: context,
                    combineSettings: settings,
                    canvas: frames.canvas,
                    edges: edges,
                    beforeRect: frames.beforeRect,
                    afterRect: frames.afterRect,
                )
            } else {
                CompositeLabelDrawer.drawIfEnabled(
                    context: context,
                    combineSettings: combineSettings,
                    beforeRect: frames.beforeRect,
                    afterRect: frames.afterRect,
                    scaleFactor: scaleFactor,
                )
            }
        }
    }

    nonisolated static func composeFrames(
        paneSizes: PaneScaledSizes,
        layout: CompositeLayout,
        borders: EdgeBorders,
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        switch layout {
            case .horizontal:
                CompositeFrameMath.horizontal(paneSizes: paneSizes, borders: borders)

            case .vertical:
                CompositeFrameMath.vertical(paneSizes: paneSizes, borders: borders)
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

nonisolated enum CompositeImageEncoder {
    static func encode(
        cgImage: CGImage,
        utType: UTType,
        quality: CGFloat,
        capturedAt: Date?,
        latitude: Double?,
        longitude: Double?,
    ) -> Data? {
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            utType.identifier as CFString,
            1,
            nil,
        ) else {
            return nil
        }
        var properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
        ]
        if let capturedAt {
            let stamp = exifTimestamp(from: capturedAt)
            properties[kCGImagePropertyExifDictionary] = [
                kCGImagePropertyExifDateTimeOriginal: stamp,
                kCGImagePropertyExifDateTimeDigitized: stamp,
            ] as [CFString: Any]
            properties[kCGImagePropertyTIFFDictionary] = [
                kCGImagePropertyTIFFDateTime: stamp,
            ] as [CFString: Any]
        }
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
