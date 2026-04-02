import CoreImage
import UIKit

enum QualityIssue {
    case blurry
    case overExposed
    case underExposed
}

@Observable
@MainActor
final class QualityCheckService {
    private(set) var lastIssue: QualityIssue?
    private(set) var isAnalyzing: Bool = false

    private let context = CIContext()

    func analyze(_ image: UIImage, isLowLight: Bool = false) async -> QualityIssue? {
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let ciContext = context

        let issue = await Task.detached(priority: .utility) {
            var result: QualityIssue?

            if let blurScore = Self.calculateBlurScore(ciImage: ciImage, context: ciContext) {
                let threshold: Double = isLowLight ? 30 : 80
                if blurScore < threshold {
                    result = .blurry
                }
            }

            if case .none = result {
                result = Self.checkExposure(ciImage: ciImage, context: ciContext)
            }

            return result
        }.value

        lastIssue = issue
        return issue
    }

    private nonisolated static func calculateBlurScore(ciImage: CIImage, context: CIContext) -> Double? {
        guard let monoFilter = CIFilter(name: "CIPhotoEffectMono", parameters: [kCIInputImageKey: ciImage]),
              let grayscale = monoFilter.outputImage else { return nil }

        let kernel: [CGFloat] = [
            0, 0, -1, 0, 0,
            0, -1, -2, -1, 0,
            -1, -2, 16, -2, -1,
            0, -1, -2, -1, 0,
            0, 0, -1, 0, 0,
        ]
        let weights = CIVector(values: kernel, count: 25)
        guard let convFilter = CIFilter(name: "CIConvolution5X5", parameters: [
            kCIInputImageKey: grayscale,
            kCIInputWeightsKey: weights,
            kCIInputBiasKey: 0.0,
        ]),
            let convOutput = convFilter.outputImage else { return nil }

        let imageExtent = ciImage.extent
        let sampleRect = imageExtent.insetBy(dx: imageExtent.width * 0.1, dy: imageExtent.height * 0.1)

        guard let avgFilter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: convOutput,
            kCIInputExtentKey: CIVector(cgRect: sampleRect),
        ]),
            let avgOutput = avgFilter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            avgOutput,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])
    }

    private nonisolated static func checkExposure(ciImage: CIImage, context: CIContext) -> QualityIssue? {
        guard let histFilter = CIFilter(name: "CIAreaHistogram", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent),
            kCIInputScaleKey: Float(1.0),
            kCIInputCountKey: Int(64),
        ]),
            let histOutput = histFilter.outputImage else { return nil }

        var histData = [UInt8](repeating: 0, count: 64 * 4)
        context.render(
            histOutput,
            toBitmap: &histData,
            rowBytes: 64 * 4,
            bounds: CGRect(x: 0, y: 0, width: 64, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var totalLuminance: Double = 0
        var darkBins: Double = 0
        var brightBins: Double = 0

        for i in 0 ..< 64 {
            let red = Double(histData[i * 4])
            let green = Double(histData[i * 4 + 1])
            let blue = Double(histData[i * 4 + 2])
            let luminance = (red + green + blue) / 3.0
            totalLuminance += luminance

            if i < 8 { darkBins += luminance }
            if i >= 56 { brightBins += luminance }
        }

        guard totalLuminance > 0 else { return nil }

        let darkRatio = darkBins / totalLuminance
        let brightRatio = brightBins / totalLuminance

        if brightRatio > 0.6 { return .overExposed }
        if darkRatio > 0.7 { return .underExposed }

        return nil
    }
}
