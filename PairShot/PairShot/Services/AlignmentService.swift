import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import Vision

nonisolated enum AlignmentService {
    private static let deviceRGBColorSpace = CGColorSpaceCreateDeviceRGB()

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

    private static func performAlign(
        beforeURL: URL,
        afterURL: URL,
        outputURL: URL,
        context: CIContext
    ) throws -> URL? {
        guard
            let beforeCG = ImageThumbnailLoader.load(url: beforeURL, maxPixelSize: 1200),
            let afterCG = ImageThumbnailLoader.load(url: afterURL, maxPixelSize: 1200)
        else {
            throw AlignmentError.loadFailed
        }

        guard let afterResized = resize(
            image: afterCG,
            to: CGSize(width: beforeCG.width, height: beforeCG.height)
        ) else { throw AlignmentError.loadFailed }

        let request = VNHomographicImageRegistrationRequest(
            targetedCGImage: afterResized,
            options: [:]
        )

        let handler = VNImageRequestHandler(
            cgImage: beforeCG,
            options: [.ciContext: context]
        )

        do {
            try handler.perform([request])
        } catch {
            throw AlignmentError.visionFailed
        }

        guard let observation = request.results?.first else {
            return nil
        }

        guard let warped = applyWarp(
            cgImage: afterResized,
            warpTransform: observation.warpTransform,
            afterSize: CGSize(width: beforeCG.width, height: beforeCG.height),
            context: context
        ) else {
            throw AlignmentError.warpFailed
        }

        guard let jpeg = makeJpegData(from: warped) else {
            throw AlignmentError.warpFailed
        }

        do {
            try jpeg.write(to: outputURL)
        } catch {
            throw AlignmentError.saveFailed
        }

        return outputURL
    }

    private static func resize(image: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: deviceRGBColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    /// Vision warpTransform은 top-left origin 픽셀 좌표계.
    /// CIFilter.perspectiveTransform의 코너는 CIImage 좌표계(bottom-left origin).
    /// 두 좌표계의 Y축이 반대이므로 Vision 결과를 CI 코너에 할당하기 전 Y flip 필요.
    private static func applyWarp(
        cgImage: CGImage,
        warpTransform: matrix_float3x3,
        afterSize: CGSize,
        context: CIContext
    ) -> CGImage? {
        let width = Float(cgImage.width)
        let height = Float(cgImage.height)
        let heightCG = CGFloat(height)

        func warpedCornerInCI(_ x: Float, _ y: Float) -> CGPoint {
            let vec = warpTransform * simd_float3(x, y, 1)
            let (warpedX, warpedY): (CGFloat, CGFloat) = vec.z != 0
                ? (CGFloat(vec.x / vec.z), CGFloat(vec.y / vec.z))
                : (CGFloat(x), CGFloat(y))
            return CGPoint(x: warpedX, y: heightCG - warpedY)
        }

        let filter = CIFilter.perspectiveTransform()
        filter.inputImage = CIImage(cgImage: cgImage)
        // Vision pixel 좌표의 각 visual corner에 warp 적용 후 Y-flip해서 CI 좌표로 전달.
        filter.topLeft = warpedCornerInCI(0, 0)
        filter.topRight = warpedCornerInCI(width, 0)
        filter.bottomRight = warpedCornerInCI(width, height)
        filter.bottomLeft = warpedCornerInCI(0, height)

        guard let outputImage = filter.outputImage else { return nil }
        let outputRect = CGRect(x: 0, y: 0, width: afterSize.width, height: afterSize.height)
        return context.createCGImage(outputImage, from: outputRect)
    }

    static func makeJpegData(from cgImage: CGImage) -> Data? {
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
}
