import CoreImage
import CoreVideo
import Observation
import QuartzCore
import Vision

@Observable
@MainActor
final class PositionMatchingService {
    private(set) var lateralDisplacementCm: Double = 0.0
    private(set) var verticalDisplacementCm: Double = 0.0
    private(set) var isActive: Bool = false

    private var referenceImage: CGImage?
    private var referenceWidth: Int = 0
    private var referenceHeight: Int = 0
    private let processingQueue = DispatchQueue(label: "com.pairshot.vision", qos: .userInitiated)
    private var lastProcessTime: CFTimeInterval = 0
    private let throttleInterval: CFTimeInterval = 0.2 // ~5fps

    func setReferenceImage(_ image: CGImage) {
        let maxDim = 540
        let scale = min(Double(maxDim) / Double(image.width), Double(maxDim) / Double(image.height), 1.0)
        if scale < 1.0 {
            let scaledWidth = Int(Double(image.width) * scale)
            let scaledHeight = Int(Double(image.height) * scale)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            if let context = CGContext(
                data: nil,
                width: scaledWidth,
                height: scaledHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) {
                context.draw(image, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
                referenceImage = context.makeImage()
                referenceWidth = scaledWidth
                referenceHeight = scaledHeight
            }
        } else {
            referenceImage = image
            referenceWidth = image.width
            referenceHeight = image.height
        }
        isActive = true
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer, depth: Double, focalLengthPx: Double) {
        guard isActive, let ref = referenceImage else { return }

        let now = CACurrentMediaTime()
        guard now - lastProcessTime >= throttleInterval else { return }
        lastProcessTime = now
        let refW = referenceWidth
        let refH = referenceHeight
        let capturedDepth = depth
        let fx = focalLengthPx

        // Convert to CIImage on main actor before crossing isolation boundary (CVBuffer is not Sendable)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let frameW = CVPixelBufferGetWidth(pixelBuffer)
        let frameH = CVPixelBufferGetHeight(pixelBuffer)

        processingQueue.async { [weak self] in
            let scaleX = Double(refW) / Double(frameW)
            let scaleY = Double(refH) / Double(frameH)
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            let ciContext = CIContext()
            guard let frameCG = ciContext.createCGImage(
                scaled, from: CGRect(x: 0, y: 0, width: refW, height: refH)
            ) else { return }

            // targeted image = floating (live frame), handler image = reference (Before)
            let request = VNTranslationalImageRegistrationRequest(targetedCGImage: frameCG, options: [:])
            let handler = VNImageRequestHandler(cgImage: ref, options: [:])

            do {
                try handler.perform([request])
                guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation
                else { return }

                // tx/ty: pixel shift to align live frame onto reference (downscaled space)
                let tx = Double(observation.alignmentTransform.tx)
                let ty = Double(observation.alignmentTransform.ty)

                // Scale back to original frame pixel space
                let txOriginal = tx / scaleX
                let tyOriginal = ty / scaleY

                guard capturedDepth > 0, fx > 0 else { return }
                let lateralCm = (txOriginal * capturedDepth / fx) * 100
                let verticalCm = (tyOriginal * capturedDepth / fx) * 100

                Task { @MainActor [weak self] in
                    self?.lateralDisplacementCm = lateralCm
                    self?.verticalDisplacementCm = verticalCm
                }
            } catch {
                // Vision request failed — skip this frame
            }
        }
    }

    func stop() {
        isActive = false
        referenceImage = nil
        lateralDisplacementCm = 0
        verticalDisplacementCm = 0
    }
}
