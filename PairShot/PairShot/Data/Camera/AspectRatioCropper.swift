import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum AspectRatioCropper {
    static func cropToAspect(
        data: Data,
        targetAspect: AspectRatio,
        utType: UTType,
    ) -> Data {
        guard targetAspect != .fourThree else { return data }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return data }
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        guard imageWidth > 0, imageHeight > 0 else { return data }

        let cropRect = centerCropRect(
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            targetAspect: targetAspect,
        )
        guard let cropped = cgImage.cropping(to: cropRect) else { return data }

        let metadata = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        return encode(
            image: cropped,
            metadata: metadata,
            utType: utType,
            compressionQuality: compressionQuality(for: utType),
        ) ?? data
    }

    static func centerCropRect(
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        targetAspect: AspectRatio,
    ) -> CGRect {
        let portraitRatio = targetAspect.portraitHeightMultiplier
        let isLandscape = imageWidth >= imageHeight
        let targetRatio: CGFloat = isLandscape ? portraitRatio : 1.0 / portraitRatio
        let currentRatio = imageWidth / imageHeight

        if abs(currentRatio - targetRatio) < 0.0001 {
            return CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        }

        if currentRatio > targetRatio {
            let newWidth = imageHeight * targetRatio
            let originX = ((imageWidth - newWidth) / 2).rounded()
            return CGRect(
                x: originX,
                y: 0,
                width: newWidth.rounded(),
                height: imageHeight,
            )
        }
        let newHeight = imageWidth / targetRatio
        let originY = ((imageHeight - newHeight) / 2).rounded()
        return CGRect(
            x: 0,
            y: originY,
            width: imageWidth,
            height: newHeight.rounded(),
        )
    }

    private static func compressionQuality(for utType: UTType) -> CGFloat {
        utType == .heic ? 1.0 : 0.95
    }

    private static func encode(
        image: CGImage,
        metadata: [CFString: Any],
        utType: UTType,
        compressionQuality: CGFloat,
    ) -> Data? {
        let mutable = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutable as CFMutableData,
            utType.identifier as CFString,
            1,
            nil,
        ) else { return nil }

        var properties = metadata
        properties[kCGImageDestinationLossyCompressionQuality] = compressionQuality
        properties[kCGImagePropertyPixelWidth] = image.width
        properties[kCGImagePropertyPixelHeight] = image.height
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutable as Data
    }
}
