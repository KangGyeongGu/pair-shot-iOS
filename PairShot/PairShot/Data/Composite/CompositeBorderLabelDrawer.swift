import CoreGraphics
import Foundation
import UIKit

extension CompositeLabelDrawer {
    nonisolated static func drawBorderEdgeLabels(
        context: UIGraphicsImageRendererContext,
        combineSettings: CombineSettings,
        canvas: CGSize,
        edges: EdgeBorders,
        beforeRect: CGRect,
        afterRect: CGRect,
    ) {
        guard combineSettings.label.isEnabled else { return }
        let layout = CompositeLayoutResolver.layout(from: combineSettings)
        let beforeStrip = borderStripRect(
            position: combineSettings.beforeBorderPosition,
            paneRect: beforeRect,
            edges: edges,
            canvas: canvas,
            layout: layout,
            isBefore: true,
        )
        let afterStrip = borderStripRect(
            position: combineSettings.afterBorderPosition,
            paneRect: afterRect,
            edges: edges,
            canvas: canvas,
            layout: layout,
            isBefore: false,
        )
        drawBorderLabel(
            text: combineSettings.label.beforeText,
            stripRect: beforeStrip,
            horizontal: combineSettings.beforeBorderPosition.horizontal,
            settings: combineSettings,
            paneHeight: beforeRect.height,
            cgContext: context.cgContext,
        )
        drawBorderLabel(
            text: combineSettings.label.afterText,
            stripRect: afterStrip,
            horizontal: combineSettings.afterBorderPosition.horizontal,
            settings: combineSettings,
            paneHeight: afterRect.height,
            cgContext: context.cgContext,
        )
    }

    nonisolated static func drawSingleBorderEdgeLabel(
        context: UIGraphicsImageRendererContext,
        combineSettings: CombineSettings,
        canvas: CGSize,
        edges: EdgeBorders,
        imageRect: CGRect,
        isBefore: Bool,
    ) {
        guard combineSettings.label.isEnabled else { return }
        let position = isBefore ? combineSettings.beforeBorderPosition : combineSettings.afterBorderPosition
        let stripRect =
            switch position.vertical {
                case .top:
                    CGRect(x: imageRect.minX, y: 0, width: imageRect.width, height: edges.top)

                case .bottom:
                    CGRect(
                        x: imageRect.minX,
                        y: canvas.height - edges.bottom,
                        width: imageRect.width,
                        height: edges.bottom,
                    )
            }
        let text = isBefore ? combineSettings.label.beforeText : combineSettings.label.afterText
        drawBorderLabel(
            text: text,
            stripRect: stripRect,
            horizontal: position.horizontal,
            settings: combineSettings,
            paneHeight: imageRect.height,
            cgContext: context.cgContext,
        )
    }

    nonisolated static func borderStripRect(
        position: CombineSettings.BorderLabelPosition,
        paneRect: CGRect,
        edges: EdgeBorders,
        canvas: CGSize,
        layout: CompositeLayout,
        isBefore: Bool,
    ) -> CGRect {
        switch layout {
            case .horizontal:
                horizontalBorderStripRect(
                    position: position,
                    paneRect: paneRect,
                    edges: edges,
                    canvas: canvas,
                )

            case .vertical:
                verticalBorderStripRect(
                    position: position,
                    paneRect: paneRect,
                    edges: edges,
                    canvas: canvas,
                    isBefore: isBefore,
                )
        }
    }

    private nonisolated static func horizontalBorderStripRect(
        position: CombineSettings.BorderLabelPosition,
        paneRect: CGRect,
        edges: EdgeBorders,
        canvas: CGSize,
    ) -> CGRect {
        switch position.vertical {
            case .top:
                CGRect(x: paneRect.minX, y: 0, width: paneRect.width, height: edges.top)

            case .bottom:
                CGRect(
                    x: paneRect.minX,
                    y: canvas.height - edges.bottom,
                    width: paneRect.width,
                    height: edges.bottom,
                )
        }
    }

    private nonisolated static func verticalBorderStripRect(
        position: CombineSettings.BorderLabelPosition,
        paneRect: CGRect,
        edges: EdgeBorders,
        canvas: CGSize,
        isBefore: Bool,
    ) -> CGRect {
        switch position.vertical {
            case .top:
                if isBefore {
                    CGRect(x: paneRect.minX, y: 0, width: paneRect.width, height: edges.top)
                } else {
                    CGRect(
                        x: paneRect.minX,
                        y: paneRect.minY - edges.middle,
                        width: paneRect.width,
                        height: edges.middle,
                    )
                }

            case .bottom:
                if isBefore {
                    CGRect(
                        x: paneRect.minX,
                        y: paneRect.maxY,
                        width: paneRect.width,
                        height: edges.middle,
                    )
                } else {
                    CGRect(
                        x: paneRect.minX,
                        y: canvas.height - edges.bottom,
                        width: paneRect.width,
                        height: edges.bottom,
                    )
                }
        }
    }

    private nonisolated static func drawBorderLabel(
        text: String,
        stripRect: CGRect,
        horizontal: CombineSettings.LabelPosition.Horizontal,
        settings: CombineSettings,
        paneHeight: CGFloat,
        cgContext: CGContext,
    ) {
        let fontSize = resolveFontSize(
            textSizePercent: settings.label.textSizePercent,
            imageHeight: paneHeight,
        )
        let attributed = makeAttributedText(text: text, settings: settings, fontSize: fontSize)
        if !settings.labelBackground.matchBorderColor {
            let bgColor = UIColor(rgba: settings.labelBackground.color)
                .withAlphaComponent(CGFloat(max(0, min(1, settings.labelBackground.opacity))))
            cgContext.saveGState()
            cgContext.setFillColor(bgColor.cgColor)
            cgContext.fill(stripRect)
            cgContext.restoreGState()
        }
        let textSize = attributed.size()
        let hPad = fontSize * LabelMetrics.horizontalPaddingFactor
        let drawX: CGFloat =
            switch horizontal {
                case .leading:
                    stripRect.minX + hPad

                case .center:
                    stripRect.midX - textSize.width / 2

                case .trailing:
                    stripRect.maxX - textSize.width - hPad
            }
        let drawY = stripRect.midY - textSize.height / 2
        attributed.draw(at: CGPoint(x: drawX, y: drawY))
    }
}
