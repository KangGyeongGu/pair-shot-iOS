import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

enum HeatmapService {
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

        guard let beforeCI = CIImage(contentsOf: beforeURL),
              let afterCI = CIImage(contentsOf: afterURL)
        else {
            throw HeatmapError.loadFailed
        }

        // 1. 절대값 차이 이미지
        let diffFilter = CIFilter.colorAbsoluteDifference()
        diffFilter.inputImage = beforeCI
        diffFilter.inputImage2 = afterCI
        guard let diffImage = diffFilter.outputImage else {
            throw HeatmapError.filterFailed
        }

        // 2. 변화율 계산: 차이 이미지를 512px 이하로 다운샘플 후 평균 휘도를 changeRatio로 사용
        let changeRatio = try computeChangeRatio(from: diffImage, context: ciContext)

        // 3. 차이 이미지를 FalseColor로 레드 오버레이 변환 (어두운 영역: 투명, 밝은 영역: 빨강)
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

        // 5. CGImage 생성
        let extent = compositeImage.extent
        guard let cgImage = ciContext.createCGImage(compositeImage, from: extent) else {
            throw HeatmapError.filterFailed
        }

        return HeatmapResult(heatmapCGImage: cgImage, changeRatio: changeRatio)
    }

    private static func computeChangeRatio(from diffImage: CIImage, context: CIContext) throws -> Double {
        let extent = diffImage.extent
        guard extent.width > 0, extent.height > 0 else { return 0 }

        // 512px 이하로 다운샘플
        let maxDimension: CGFloat = 512
        let scale = min(maxDimension / max(extent.width, extent.height), 1.0)

        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = diffImage
        scaleFilter.scale = Float(scale)
        scaleFilter.aspectRatio = 1.0
        guard let scaledImage = scaleFilter.outputImage else { return 0 }

        // 평균 색상으로 변화율 근사 (R, G, B 채널 평균 → 전체 변화 강도)
        let avgFilter = CIFilter.areaAverage()
        avgFilter.inputImage = scaledImage
        avgFilter.extent = scaledImage.extent
        guard let avgOutput = avgFilter.outputImage else { return 0 }

        // 1x1 픽셀 이미지에서 RGBA 값 추출
        var pixel = [UInt8](repeating: 0, count: 4)
        let renderRect = CGRect(x: avgOutput.extent.minX, y: avgOutput.extent.minY, width: 1, height: 1)
        context.render(
            avgOutput,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: renderRect,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let avgR = Double(pixel[0]) / 255.0
        let avgG = Double(pixel[1]) / 255.0
        let avgB = Double(pixel[2]) / 255.0
        // 세 채널 평균을 변화 강도로 사용 (0.0~1.0)
        let avgLuminance = (avgR + avgG + avgB) / 3.0
        return min(avgLuminance, 1.0)
    }
}
