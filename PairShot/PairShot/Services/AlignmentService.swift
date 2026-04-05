import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import Vision

enum AlignmentService {
    enum AlignmentError: Error {
        case loadFailed
        case visionFailed
        case warpFailed
        case saveFailed
    }

    static func align(
        beforeURL: URL,
        afterURL: URL,
        outputURL: URL
    ) async throws -> URL? {
        let ctx = ImageProcessingContext.shared
        return try await Task.detached(priority: .userInitiated) {
            try performAlign(
                beforeURL: beforeURL,
                afterURL: afterURL,
                outputURL: outputURL,
                context: ctx
            )
        }.value
    }
}

private nonisolated func performAlign(
    beforeURL: URL,
    afterURL: URL,
    outputURL: URL,
    context: CIContext
) throws -> URL? {
    guard
        let beforeCG = loadThumbnail(url: beforeURL, maxPixelSize: 1200),
        let afterCG = loadThumbnail(url: afterURL, maxPixelSize: 1200)
    else {
        throw AlignmentService.AlignmentError.loadFailed
    }

    guard let beforeResized = resize(
        image: beforeCG,
        to: CGSize(width: afterCG.width, height: afterCG.height)
    ) else { throw AlignmentService.AlignmentError.loadFailed }

    let request = VNHomographicImageRegistrationRequest(
        targetedCGImage: beforeResized,
        options: [:]
    )

    let handler = VNImageRequestHandler(
        cgImage: afterCG,
        options: [.ciContext: context]
    )

    do {
        try handler.perform([request])
    } catch {
        throw AlignmentService.AlignmentError.visionFailed
    }

    guard let observation = request.results?.first else {
        return nil
    }

    guard let warped = applyWarp(cgImage: beforeResized, warpTransform: observation.warpTransform, context: context)
    else {
        throw AlignmentService.AlignmentError.warpFailed
    }

    guard let jpeg = makeJpegData(from: warped) else {
        throw AlignmentService.AlignmentError.warpFailed
    }

    do {
        try jpeg.write(to: outputURL)
    } catch {
        throw AlignmentService.AlignmentError.saveFailed
    }

    return outputURL
}

private nonisolated func loadThumbnail(url: URL, maxPixelSize: Int) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
}

private nonisolated func resize(image: CGImage, to size: CGSize) -> CGImage? {
    let width = Int(size.width)
    let height = Int(size.height)
    guard width > 0, height > 0 else { return nil }
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    context.draw(image, in: CGRect(origin: .zero, size: size))
    return context.makeImage()
}

/// Multiply each corner by matrix_float3x3, divide by homogeneous z to get Cartesian coords
private nonisolated func applyWarp(cgImage: CGImage, warpTransform: matrix_float3x3, context: CIContext) -> CGImage? {
    let w = Float(cgImage.width)
    let h = Float(cgImage.height)

    func toPoint(_ x: Float, _ y: Float) -> CGPoint {
        let v = warpTransform * simd_float3(x, y, 1)
        guard v.z != 0 else { return CGPoint(x: CGFloat(x), y: CGFloat(y)) }
        return CGPoint(x: CGFloat(v.x / v.z), y: CGFloat(v.y / v.z))
    }

    let filter = CIFilter.perspectiveTransform()
    filter.inputImage = CIImage(cgImage: cgImage)
    filter.topLeft = toPoint(0, 0)
    filter.topRight = toPoint(w, 0)
    filter.bottomRight = toPoint(w, h)
    filter.bottomLeft = toPoint(0, h)

    guard let outputImage = filter.outputImage else { return nil }
    return context.createCGImage(outputImage, from: outputImage.extent)
}

private nonisolated func makeJpegData(from cgImage: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data as CFMutableData,
        "public.jpeg" as CFString,
        1,
        nil
    ) else { return nil }
    CGImageDestinationAddImage(
        destination,
        cgImage,
        [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
}
