import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

enum ColorCorrectionService {
    enum ColorCorrectionError: Error {
        case loadFailed
        case filterFailed
        case saveFailed
    }

    static func correct(
        beforeURL: URL,
        referenceAfterURL: URL,
        outputURL: URL
    ) async throws -> URL? {
        let ctx = ImageProcessingContext.shared
        return try await Task.detached(priority: .userInitiated) {
            try performCorrection(
                beforeURL: beforeURL,
                referenceAfterURL: referenceAfterURL,
                outputURL: outputURL,
                context: ctx
            )
        }.value
    }
}

private nonisolated func performCorrection(
    beforeURL: URL,
    referenceAfterURL: URL,
    outputURL: URL,
    context: CIContext
) throws -> URL? {
    guard let beforeImage = CIImage(contentsOf: beforeURL),
          let afterImage = CIImage(contentsOf: referenceAfterURL)
    else {
        throw ColorCorrectionService.ColorCorrectionError.loadFailed
    }

    let corrected = applyColorCorrection(to: beforeImage, reference: afterImage, context: context)

    guard let cgImage = context.createCGImage(corrected, from: corrected.extent) else {
        throw ColorCorrectionService.ColorCorrectionError.filterFailed
    }

    let uiImage = UIImage(cgImage: cgImage)
    guard let jpegData = uiImage.jpegData(compressionQuality: 0.9) else {
        throw ColorCorrectionService.ColorCorrectionError.saveFailed
    }

    do {
        try jpegData.write(to: outputURL, options: .atomic)
    } catch {
        throw ColorCorrectionService.ColorCorrectionError.saveFailed
    }

    return outputURL
}

private nonisolated func applyColorCorrection(to image: CIImage, reference: CIImage, context: CIContext) -> CIImage {
    // Step 1: autoAdjustmentFilters for base lighting correction
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

    // Step 2: match average color of reference (after) using CIColorMatrix
    guard let beforeAvg = averageColor(of: autoAdjusted, context: context),
          let afterAvg = averageColor(of: reference, context: context),
          beforeAvg.r > 0, beforeAvg.g > 0, beforeAvg.b > 0
    else {
        return autoAdjusted
    }

    let rScale = afterAvg.r / beforeAvg.r
    let gScale = afterAvg.g / beforeAvg.g
    let bScale = afterAvg.b / beforeAvg.b

    let matrixFilter = CIFilter.colorMatrix()
    matrixFilter.inputImage = autoAdjusted
    matrixFilter.rVector = CIVector(x: CGFloat(rScale), y: 0, z: 0, w: 0)
    matrixFilter.gVector = CIVector(x: 0, y: CGFloat(gScale), z: 0, w: 0)
    matrixFilter.bVector = CIVector(x: 0, y: 0, z: CGFloat(bScale), w: 0)
    matrixFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
    matrixFilter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)

    return matrixFilter.outputImage ?? autoAdjusted
}

private struct RGBA {
    let r: Float
    let g: Float
    let b: Float
}

private nonisolated func averageColor(of image: CIImage, context: CIContext) -> RGBA? {
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
        colorSpace: CGColorSpaceCreateDeviceRGB()
    )

    guard bitmap[3] > 0 else { return nil }

    return RGBA(
        r: max(Float(bitmap[0]) / 255.0, 1e-6),
        g: max(Float(bitmap[1]) / 255.0, 1e-6),
        b: max(Float(bitmap[2]) / 255.0, 1e-6)
    )
}
