import CoreGraphics
import Foundation

nonisolated struct PaneScaledSizes: Equatable {
    let before: CGSize
    let after: CGSize
}

nonisolated struct EdgeBorders: Equatable {
    var top: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    var right: CGFloat
    var middle: CGFloat

    mutating func applyHorizontalStrip(
        vertical: CombineSettings.BorderLabelPosition.Vertical,
        strip: CGFloat,
    ) {
        switch vertical {
            case .top: top = max(top, strip)
            case .bottom: bottom = max(bottom, strip)
        }
    }

    mutating func applyVerticalBeforeStrip(
        vertical: CombineSettings.BorderLabelPosition.Vertical,
        strip: CGFloat,
    ) {
        switch vertical {
            case .top: top = max(top, strip)
            case .bottom: middle = max(middle, strip)
        }
    }

    mutating func applyVerticalAfterStrip(
        vertical: CombineSettings.BorderLabelPosition.Vertical,
        strip: CGFloat,
    ) {
        switch vertical {
            case .top: middle = max(middle, strip)
            case .bottom: bottom = max(bottom, strip)
        }
    }

    static func uniform(_ value: CGFloat) -> Self {
        Self(top: value, bottom: value, left: value, right: value, middle: value)
    }

    static func compute(
        paneSizes: PaneScaledSizes,
        layout: CompositeLayout,
        settings: CombineSettings?,
        scaleFactor: CGFloat,
    ) -> Self {
        let basePx = CGFloat(CompositeLabelDrawer.resolveBorderPx(settings)) * scaleFactor
        var edges = Self.uniform(basePx)

        guard
            let settings,
            settings.label.isEnabled,
            settings.labelPlacement == .border
        else {
            return edges
        }

        let beforeStrip = CompositeLabelDrawer.labelStripPx(
            textSizePercent: settings.label.textSizePercent,
            paneHeight: paneSizes.before.height,
        )
        let afterStrip = CompositeLabelDrawer.labelStripPx(
            textSizePercent: settings.label.textSizePercent,
            paneHeight: paneSizes.after.height,
        )

        switch layout {
            case .horizontal:
                edges.applyHorizontalStrip(vertical: settings.beforeBorderPosition.vertical, strip: beforeStrip)
                edges.applyHorizontalStrip(vertical: settings.afterBorderPosition.vertical, strip: afterStrip)

            case .vertical:
                edges.applyVerticalBeforeStrip(vertical: settings.beforeBorderPosition.vertical, strip: beforeStrip)
                edges.applyVerticalAfterStrip(vertical: settings.afterBorderPosition.vertical, strip: afterStrip)
        }
        return edges
    }
}

nonisolated enum CompositeFrameMath {
    static func paneScaledSizes(
        beforeSize: CGSize,
        afterSize: CGSize,
        layout: CompositeLayout,
    ) -> PaneScaledSizes {
        let beforeWidth = max(beforeSize.width, 1)
        let beforeHeight = max(beforeSize.height, 1)
        let afterWidth = max(afterSize.width, 1)
        let afterHeight = max(afterSize.height, 1)
        switch layout {
            case .horizontal:
                let common = min(beforeHeight, afterHeight)
                return PaneScaledSizes(
                    before: CGSize(width: beforeWidth * (common / beforeHeight), height: common),
                    after: CGSize(width: afterWidth * (common / afterHeight), height: common),
                )

            case .vertical:
                let common = min(beforeWidth, afterWidth)
                return PaneScaledSizes(
                    before: CGSize(width: common, height: beforeHeight * (common / beforeWidth)),
                    after: CGSize(width: common, height: afterHeight * (common / afterWidth)),
                )
        }
    }

    static func horizontal(
        paneSizes: PaneScaledSizes,
        borders: EdgeBorders,
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        let before = paneSizes.before
        let after = paneSizes.after
        let canvas = CGSize(
            width: borders.left + before.width + borders.middle + after.width + borders.right,
            height: borders.top + max(before.height, after.height) + borders.bottom,
        )
        let beforeRect = CGRect(
            x: borders.left,
            y: borders.top,
            width: before.width,
            height: before.height,
        )
        let afterRect = CGRect(
            x: borders.left + before.width + borders.middle,
            y: borders.top,
            width: after.width,
            height: after.height,
        )
        return (canvas, beforeRect, afterRect)
    }

    static func vertical(
        paneSizes: PaneScaledSizes,
        borders: EdgeBorders,
    ) -> (canvas: CGSize, beforeRect: CGRect, afterRect: CGRect) {
        let before = paneSizes.before
        let after = paneSizes.after
        let canvas = CGSize(
            width: borders.left + max(before.width, after.width) + borders.right,
            height: borders.top + before.height + borders.middle + after.height + borders.bottom,
        )
        let beforeRect = CGRect(
            x: borders.left,
            y: borders.top,
            width: before.width,
            height: before.height,
        )
        let afterRect = CGRect(
            x: borders.left,
            y: borders.top + before.height + borders.middle,
            width: after.width,
            height: after.height,
        )
        return (canvas, beforeRect, afterRect)
    }
}
