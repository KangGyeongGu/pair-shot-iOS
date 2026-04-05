import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

nonisolated enum HeatmapService {
    private static let deviceRGBColorSpace = CGColorSpaceCreateDeviceRGB()

    enum HeatmapError: Error { case loadFailed, filterFailed }

    struct HeatmapResult {
        let heatmapCGImage: CGImage
        let changeRatio: Double
    }

    static func generateHeatmap(
        beforeURL: URL,
        afterURL: URL
    ) async throws -> HeatmapResult {
        let ciContext = ImageProcessingContext.shared
        return try await Task.detached(priority: .userInitiated) {
            guard
                let beforeCG = ImageThumbnailLoader.load(url: beforeURL, maxPixelSize: 1200),
                let afterCG = ImageThumbnailLoader.load(url: afterURL, maxPixelSize: 1200)
            else {
                throw HeatmapError.loadFailed
            }

            let beforeCI = CIImage(cgImage: beforeCG)
            let afterCI = CIImage(cgImage: afterCG)

            // 1. 절대값 차이 이미지
            let diffFilter = CIFilter.colorAbsoluteDifference()
            diffFilter.inputImage = beforeCI
            diffFilter.inputImage2 = afterCI
            guard let diffImage = diffFilter.outputImage else {
                throw HeatmapError.filterFailed
            }

            // 2. 변화율 계산
            let changeRatio = computeChangeRatio(from: diffImage, context: ciContext)

            // 3. 차이 이미지를 FalseColor로 레드 오버레이 변환
            let falseColorFilter = CIFilter.falseColor()
            falseColorFilter.inputImage = diffImage
            falseColorFilter.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
            falseColorFilter.color1 = CIColor(red: 1, green: 0, blue: 0, alpha: 0.8)
            guard let redOverlay = falseColorFilter.outputImage else {
                throw HeatmapError.filterFailed
            }

            // 4. after 이미지 위에 레드 오버레이 합성
            let compositeFilter = CIFilter.sourceOverCompositing()
            compositeFilter.inputImage = redOverlay
            compositeFilter.backgroundImage = afterCI
            guard let compositeImage = compositeFilter.outputImage else {
                throw HeatmapError.filterFailed
            }

            // 5. CGImage 생성 (after 크기로 crop)
            let outputRect = CGRect(x: 0, y: 0, width: afterCG.width, height: afterCG.height)
            guard let cgImage = ciContext.createCGImage(compositeImage, from: outputRect) else {
                throw HeatmapError.filterFailed
            }

            return HeatmapResult(heatmapCGImage: cgImage, changeRatio: changeRatio)
        }.value
    }

    private static func computeChangeRatio(from diffImage: CIImage, context: CIContext) -> Double {
        let extent = diffImage.extent
        guard extent.width > 0, extent.height > 0 else { return 0 }

        // grayscale (max of R/G/B channels)
        let maxCompFilter = CIFilter.maximumComponent()
        maxCompFilter.inputImage = diffImage
        guard let grayImage = maxCompFilter.outputImage else { return 0 }

        // 임계값(0.1) 이진화 → 임계 초과 픽셀은 1, 이하는 0
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = grayImage
        thresholdFilter.threshold = 0.1
        guard let binaryImage = thresholdFilter.outputImage else { return 0 }

        let maxDimension: CGFloat = 512
        let scale = min(maxDimension / max(extent.width, extent.height), 1.0)

        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = binaryImage
        scaleFilter.scale = Float(scale)
        scaleFilter.aspectRatio = 1.0
        guard let scaledImage = scaleFilter.outputImage else { return 0 }

        let avgFilter = CIFilter.areaAverage()
        avgFilter.inputImage = scaledImage
        avgFilter.extent = scaledImage.extent
        guard let avgOutput = avgFilter.outputImage else { return 0 }

        var pixel = [UInt8](repeating: 0, count: 4)
        let renderRect = CGRect(x: avgOutput.extent.minX, y: avgOutput.extent.minY, width: 1, height: 1)
        context.render(
            avgOutput,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: renderRect,
            format: .RGBA8,
            colorSpace: deviceRGBColorSpace
        )

        // 이진 마스크 평균 = 임계 초과 픽셀 비율
        return Double(pixel[0]) / 255.0
    }
}
