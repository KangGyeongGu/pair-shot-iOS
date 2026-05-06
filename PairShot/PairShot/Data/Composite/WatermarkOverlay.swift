import CoreGraphics
import Foundation
import UIKit

nonisolated enum WatermarkOverlay {
    static func apply(to source: UIImage, settings: WatermarkSettings) -> UIImage {
        let canvasSize = source.size
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return source
        }

        switch settings.type {
            case .text:
                return applyText(source: source, settings: settings, canvasSize: canvasSize)

            case .logo:
                return applyLogo(source: source, settings: settings, canvasSize: canvasSize)
        }
    }

    private static func applyText(
        source: UIImage,
        settings: WatermarkSettings,
        canvasSize: CGSize
    ) -> UIImage {
        guard !settings.text.isEmpty else { return source }
        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: canvasSize))
            drawDiagonalRepeatingText(
                text: settings.text,
                opacity: settings.opacity,
                lineCount: settings.lineCount,
                repeatCount: settings.repeatCount,
                textSizeRatio: settings.textSizeRatio,
                canvas: canvasSize
            )
        }
    }

    private static func applyLogo(
        source: UIImage,
        settings: WatermarkSettings,
        canvasSize: CGSize
    ) -> UIImage {
        guard let data = settings.logoImageData,
              let logo = UIImage(data: data),
              logo.size.width > 0,
              logo.size.height > 0
        else { return source }

        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: canvasSize))
            drawLogo(
                logo: logo,
                widthRatio: settings.logoWidthRatio,
                alpha: settings.logoAlpha,
                position: settings.logoPosition,
                canvas: canvasSize
            )
        }
    }

    private static func drawDiagonalRepeatingText(
        text: String,
        opacity: Double,
        lineCount: Int,
        repeatCount: Double,
        textSizeRatio: Double,
        canvas: CGSize
    ) {
        let safeRatio = max(
            WatermarkSettings.textSizeRatioRange.lowerBound,
            min(WatermarkSettings.textSizeRatioRange.upperBound, textSizeRatio)
        )
        let fontSize = max(14, canvas.width * CGFloat(safeRatio))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(CGFloat(max(0, min(1, opacity)))),
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        guard textSize.width > 0, textSize.height > 0 else { return }

        let safeLineCount = max(1, lineCount)
        let safeRepeatDensity = max(0.1, repeatCount)
        let diagonal = sqrt(canvas.width * canvas.width + canvas.height * canvas.height)
        let lineSpacing = diagonal / CGFloat(safeLineCount + 1)
        let textSpacing = max(textSize.width * CGFloat(2.0 / safeRepeatDensity), textSize.width + 16)

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.translateBy(x: canvas.width / 2, y: canvas.height / 2)
        context.rotate(by: -.pi / 4)
        context.translateBy(x: -canvas.width / 2, y: -canvas.height / 2)

        let extendedWidth = canvas.width * 1.5
        let extendedHeight = canvas.height * 1.5
        let originX = -canvas.width * 0.25
        let originY = -canvas.height * 0.25

        var y = originY
        while y < originY + extendedHeight {
            var x = originX
            while x < originX + extendedWidth {
                attributed.draw(at: CGPoint(x: x, y: y))
                x += textSpacing
            }
            y += lineSpacing
        }
        context.restoreGState()
    }

    private static func drawLogo(
        logo: UIImage,
        widthRatio: Double,
        alpha: Double,
        position: LogoPosition,
        canvas: CGSize
    ) {
        let safeRatio = max(
            WatermarkSettings.logoWidthRatioRange.lowerBound,
            min(WatermarkSettings.logoWidthRatioRange.upperBound, widthRatio)
        )
        let targetWidth = canvas.width * CGFloat(safeRatio)
        let aspect = logo.size.height / logo.size.width
        let targetHeight = targetWidth * aspect
        let padding = canvas.width * 0.02
        let rect = logoRect(
            position: position,
            canvas: canvas,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            padding: padding
        )
        let safeAlpha = CGFloat(max(0, min(1, alpha)))
        logo.draw(in: rect, blendMode: .normal, alpha: safeAlpha)
    }

    private static func logoRect(
        position: LogoPosition,
        canvas: CGSize,
        targetWidth: CGFloat,
        targetHeight: CGFloat,
        padding: CGFloat
    ) -> CGRect {
        let originX: CGFloat
        let originY: CGFloat
        switch position {
            case .topLeft:
                originX = padding
                originY = padding

            case .topCenter:
                originX = (canvas.width - targetWidth) / 2
                originY = padding

            case .topRight:
                originX = canvas.width - targetWidth - padding
                originY = padding

            case .centerLeft:
                originX = padding
                originY = (canvas.height - targetHeight) / 2

            case .center:
                originX = (canvas.width - targetWidth) / 2
                originY = (canvas.height - targetHeight) / 2

            case .centerRight:
                originX = canvas.width - targetWidth - padding
                originY = (canvas.height - targetHeight) / 2

            case .bottomLeft:
                originX = padding
                originY = canvas.height - targetHeight - padding

            case .bottomCenter:
                originX = (canvas.width - targetWidth) / 2
                originY = canvas.height - targetHeight - padding

            case .bottomRight:
                originX = canvas.width - targetWidth - padding
                originY = canvas.height - targetHeight - padding
        }
        return CGRect(x: originX, y: originY, width: targetWidth, height: targetHeight)
    }
}
