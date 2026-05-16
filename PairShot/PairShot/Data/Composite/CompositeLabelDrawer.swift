import CoreGraphics
import Foundation
import UIKit

nonisolated enum CompositeLabelDrawer {
    private enum LabelMetrics {
        static let minFontSize: CGFloat = 10
        static let rectHeightFactor: CGFloat = 1.6
        static let horizontalPaddingFactor: CGFloat = 0.75
        static let marginFactor: CGFloat = 0.4
    }

    struct LabelDrawContext {
        let text: String
        let imageRect: CGRect
        let settings: CombineSettings
        let isBefore: Bool
        let cgContext: CGContext
        let scaleFactor: CGFloat
    }

    static func drawIfEnabled(
        context: UIGraphicsImageRendererContext,
        combineSettings: CombineSettings?,
        beforeRect: CGRect,
        afterRect: CGRect,
        scaleFactor: CGFloat = 1
    ) {
        guard let settings = combineSettings, settings.label.isEnabled else { return }
        drawLabel(
            LabelDrawContext(
                text: settings.label.beforeText,
                imageRect: beforeRect,
                settings: settings,
                isBefore: true,
                cgContext: context.cgContext,
                scaleFactor: scaleFactor
            )
        )
        drawLabel(
            LabelDrawContext(
                text: settings.label.afterText,
                imageRect: afterRect,
                settings: settings,
                isBefore: false,
                cgContext: context.cgContext,
                scaleFactor: scaleFactor
            )
        )
    }

    static func drawSingleIfEnabled(
        context: UIGraphicsImageRendererContext,
        combineSettings: CombineSettings?,
        imageRect: CGRect,
        isBefore: Bool,
        scaleFactor: CGFloat = 1
    ) {
        guard let settings = combineSettings, settings.label.isEnabled else { return }
        let text = isBefore ? settings.label.beforeText : settings.label.afterText
        drawLabel(
            LabelDrawContext(
                text: text,
                imageRect: imageRect,
                settings: settings,
                isBefore: isBefore,
                cgContext: context.cgContext,
                scaleFactor: scaleFactor
            )
        )
    }

    static func resolveBorderPx(_ combineSettings: CombineSettings?) -> CGFloat {
        guard let settings = combineSettings, settings.border.isEnabled else { return 0 }
        return CGFloat(max(settings.border.thickness, 0))
    }

    static func paintCanvasBackground(
        context: UIGraphicsImageRendererContext,
        canvas: CGSize,
        combineSettings: CombineSettings?
    ) {
        let fill: UIColor =
            if let settings = combineSettings, settings.border.isEnabled {
                UIColor(rgba: settings.border.color)
            } else {
                .black
            }
        fill.setFill()
        context.fill(CGRect(origin: .zero, size: canvas))
    }

    private static func drawLabel(_ ctx: LabelDrawContext) {
        let fontSize = max(
            CGFloat(ctx.settings.label.textSizePercent) * 0.01 * ctx.imageRect.height,
            LabelMetrics.minFontSize
        )
        let attributed = makeAttributedText(text: ctx.text, settings: ctx.settings, fontSize: fontSize)
        let isFree = ctx.settings.labelMode == .free
        let labelRect = computeLabelRect(
            imageRect: ctx.imageRect,
            settings: ctx.settings,
            isFree: isFree,
            isBefore: ctx.isBefore,
            fontSize: fontSize,
            attributed: attributed
        )
        if ctx.settings.labelBackground.isEnabled {
            drawLabelBackground(
                cgContext: ctx.cgContext,
                settings: ctx.settings,
                labelRect: labelRect,
                isFree: isFree,
                scaleFactor: ctx.scaleFactor
            )
        }
        let textSize = attributed.size()
        let drawX = labelRect.midX - textSize.width / 2
        let drawY = labelRect.midY - textSize.height / 2
        attributed.draw(at: CGPoint(x: drawX, y: drawY))
    }

    private static func makeAttributedText(
        text: String,
        settings: CombineSettings,
        fontSize: CGFloat
    ) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let textColor = UIColor(rgba: settings.label.textColor)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func computeLabelRect(
        imageRect: CGRect,
        settings: CombineSettings,
        isFree: Bool,
        isBefore: Bool,
        fontSize: CGFloat,
        attributed: NSAttributedString
    ) -> CGRect {
        if isFree {
            let anchor = isBefore ? settings.beforePosition : settings.afterPosition
            return anchoredLabelRect(
                imageRect: imageRect,
                fontSize: fontSize,
                attributed: attributed,
                anchor: anchor
            )
        }
        return fullWidthLabelRect(
            imageRect: imageRect,
            fontSize: fontSize,
            vertical: settings.fullWidthVertical
        )
    }

    private static func drawLabelBackground(
        cgContext: CGContext,
        settings: CombineSettings,
        labelRect: CGRect,
        isFree: Bool,
        scaleFactor: CGFloat
    ) {
        let bgColor = effectiveLabelBgColor(settings: settings)
            .withAlphaComponent(CGFloat(max(0, min(1, settings.labelBackground.opacity))))
        cgContext.saveGState()
        cgContext.setFillColor(bgColor.cgColor)
        if isFree, settings.labelBackground.cornerRadius > 0 {
            let radius = CGFloat(settings.labelBackground.cornerRadius) * scaleFactor
            let path = UIBezierPath(roundedRect: labelRect, cornerRadius: radius)
            cgContext.addPath(path.cgPath)
            cgContext.fillPath()
        } else {
            cgContext.fill(labelRect)
        }
        cgContext.restoreGState()
    }

    private static func effectiveLabelBgColor(settings: CombineSettings) -> UIColor {
        if settings.labelBackground.matchBorderColor {
            return UIColor(rgba: settings.border.color)
        }
        return UIColor(rgba: settings.labelBackground.color)
    }

    private static func fullWidthLabelRect(
        imageRect: CGRect,
        fontSize: CGFloat,
        vertical: CombineSettings.LabelPosition.Vertical
    ) -> CGRect {
        let rectHeight = fontSize * LabelMetrics.rectHeightFactor
        let top: CGFloat =
            switch vertical {
                case .top:
                    imageRect.minY

                case .middle:
                    imageRect.midY - rectHeight / 2

                case .bottom:
                    imageRect.maxY - rectHeight
            }
        return CGRect(x: imageRect.minX, y: top, width: imageRect.width, height: rectHeight)
    }

    private static func anchoredLabelRect(
        imageRect: CGRect,
        fontSize: CGFloat,
        attributed: NSAttributedString,
        anchor: CombineSettings.LabelPosition
    ) -> CGRect {
        let rectHeight = fontSize * LabelMetrics.rectHeightFactor
        let textSize = attributed.size()
        let hPad = fontSize * LabelMetrics.horizontalPaddingFactor
        let rectWidth = max(textSize.width + hPad * 2, rectHeight)
        let margin = fontSize * LabelMetrics.marginFactor
        let leftX = anchoredLeftX(
            anchor: anchor,
            imageRect: imageRect,
            rectWidth: rectWidth,
            margin: margin
        )
        let topY = anchoredTopY(
            anchor: anchor,
            imageRect: imageRect,
            rectHeight: rectHeight,
            margin: margin
        )
        return CGRect(x: leftX, y: topY, width: rectWidth, height: rectHeight)
    }

    private static func anchoredLeftX(
        anchor: CombineSettings.LabelPosition,
        imageRect: CGRect,
        rectWidth: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        switch anchor.horizontal {
            case .leading:
                imageRect.minX + margin

            case .center:
                imageRect.minX + (imageRect.width - rectWidth) / 2

            case .trailing:
                imageRect.maxX - rectWidth - margin
        }
    }

    private static func anchoredTopY(
        anchor: CombineSettings.LabelPosition,
        imageRect: CGRect,
        rectHeight: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        switch anchor.vertical {
            case .top:
                imageRect.minY + margin

            case .middle:
                imageRect.midY - rectHeight / 2

            case .bottom:
                imageRect.maxY - rectHeight - margin
        }
    }
}
