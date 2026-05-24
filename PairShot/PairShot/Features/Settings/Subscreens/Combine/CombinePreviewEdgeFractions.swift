import Foundation

struct EdgeBorderFractions {
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
        for settings: CombineSettings,
        referenceImageWidth: CGFloat,
        representativeImageAspect: CGFloat,
    ) -> Self {
        let base = settings.border.isEnabled
            ? CGFloat(settings.border.thickness) / referenceImageWidth
            : 0
        var fractions = Self.uniform(base)

        guard settings.label.isEnabled, settings.labelPlacement == .border else { return fractions }

        let paneHeightFraction: CGFloat = 1 / representativeImageAspect
        let textPercent = CGFloat(settings.label.textSizePercent) * 0.01
        let strip = textPercent * paneHeightFraction * (1.6 + 0.4 * 2)

        switch settings.direction {
            case .horizontal:
                fractions.applyHorizontalStrip(
                    vertical: settings.beforeBorderPosition.vertical,
                    strip: strip,
                )
                fractions.applyHorizontalStrip(
                    vertical: settings.afterBorderPosition.vertical,
                    strip: strip,
                )

            case .vertical:
                fractions.applyVerticalBeforeStrip(
                    vertical: settings.beforeBorderPosition.vertical,
                    strip: strip,
                )
                fractions.applyVerticalAfterStrip(
                    vertical: settings.afterBorderPosition.vertical,
                    strip: strip,
                )
        }
        return fractions
    }
}

struct EdgeBordersPx {
    let top: CGFloat
    let bottom: CGFloat
    let left: CGFloat
    let right: CGFloat
    let middle: CGFloat
}
