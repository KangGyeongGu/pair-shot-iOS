import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO

nonisolated enum ColorCorrectionService {
    private static let deviceRGBColorSpace = CGColorSpaceCreateDeviceRGB()

    enum ColorCorrectionError: Error {
        case loadFailed
        case filterFailed
        case saveFailed
    }

    static func correct(
        afterURL: URL,
        referenceBeforeURL: URL,
        outputURL: URL
    ) async throws -> URL? {
        let ctx = ImageProcessingContext.shared
        return try await Task.detached(priority: .userInitiated) {
            try performCorrection(
                afterURL: afterURL,
                referenceBeforeURL: referenceBeforeURL,
                outputURL: outputURL,
                context: ctx
            )
        }.value
    }

    private static func performCorrection(
        afterURL: URL,
        referenceBeforeURL: URL,
        outputURL: URL,
        context: CIContext
    ) throws -> URL? {
        guard
            let afterCG = ImageThumbnailLoader.load(url: afterURL, maxPixelSize: 1200),
            let beforeCG = ImageThumbnailLoader.load(url: referenceBeforeURL, maxPixelSize: 1200)
        else {
            throw ColorCorrectionError.loadFailed
        }

        let afterImage = CIImage(cgImage: afterCG)
        let beforeImage = CIImage(cgImage: beforeCG)

        let corrected = applyColorCorrection(to: afterImage, reference: beforeImage, context: context)

        guard let cgImage = context.createCGImage(corrected, from: corrected.extent) else {
            throw ColorCorrectionError.filterFailed
        }

        guard let jpegData = AlignmentService.makeJpegData(from: cgImage) else {
            throw ColorCorrectionError.saveFailed
        }

        do {
            try jpegData.write(to: outputURL, options: .atomic)
        } catch {
            throw ColorCorrectionError.saveFailed
        }

        return outputURL
    }

    private static func applyColorCorrection(
        to image: CIImage,
        reference: CIImage,
        context: CIContext
    ) -> CIImage {
        let autoFilters = image.autoAdjustmentFilters(options: [
            .enhance: true,
            .redEye: false,
            .crop: false,
            .level: true,
        ])

        var autoAdjusted = image
        for filter in autoFilters {
            filter.setValue(autoAdjusted, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                autoAdjusted = output
            }
        }

        guard let beforeAvg = averageColor(of: autoAdjusted, context: context),
              let afterAvg = averageColor(of: reference, context: context),
              beforeAvg.red > 0, beforeAvg.green > 0, beforeAvg.blue > 0
        else {
            return autoAdjusted
        }

        let rScale = clampScale(afterAvg.red / beforeAvg.red)
        let gScale = clampScale(afterAvg.green / beforeAvg.green)
        let bScale = clampScale(afterAvg.blue / beforeAvg.blue)

        let matrixFilter = CIFilter.colorMatrix()
        matrixFilter.inputImage = autoAdjusted
        matrixFilter.rVector = CIVector(x: CGFloat(rScale), y: 0, z: 0, w: 0)
        matrixFilter.gVector = CIVector(x: 0, y: CGFloat(gScale), z: 0, w: 0)
        matrixFilter.bVector = CIVector(x: 0, y: 0, z: CGFloat(bScale), w: 0)
        matrixFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrixFilter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)

        return matrixFilter.outputImage ?? autoAdjusted
    }

    private static func clampScale(_ value: Float) -> Float {
        min(max(value, 0.5), 2.0)
    }

    private struct RGBA {
        let red: Float
        let green: Float
        let blue: Float
    }

    private static func averageColor(of image: CIImage, context: CIContext) -> RGBA? {
        let areaFilter = CIFilter.areaAverage()
        areaFilter.inputImage = image
        areaFilter.extent = image.extent

        guard let output = areaFilter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: deviceRGBColorSpace
        )

        guard bitmap[3] > 0 else { return nil }

        return RGBA(
            red: max(Float(bitmap[0]) / 255.0, 1e-6),
            green: max(Float(bitmap[1]) / 255.0, 1e-6),
            blue: max(Float(bitmap[2]) / 255.0, 1e-6)
        )
    }
}
