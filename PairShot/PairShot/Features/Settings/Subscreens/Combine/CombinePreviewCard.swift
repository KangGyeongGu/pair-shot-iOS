import SwiftUI

struct CombinePreviewCard: View {
    static let referenceImageWidth: CGFloat = 1024
    private static let representativeImageAspect: CGFloat = 4.0 / 3.0

    let settings: CombineSettings

    private var paneCountAcrossWidth: CGFloat {
        switch settings.direction {
            case .horizontal: 2
            case .vertical: 1
        }
    }

    private var paneCountAcrossHeight: CGFloat {
        switch settings.direction {
            case .horizontal: 1
            case .vertical: 2
        }
    }

    private var canvasAspectRatio: CGFloat {
        let thickness = settings.border.isEnabled ? CGFloat(settings.border.thickness) : 0
        let thicknessFraction = thickness / Self.referenceImageWidth
        let widthFraction = paneCountAcrossWidth + thicknessFraction * (paneCountAcrossWidth + 1)
        let heightFraction = paneCountAcrossHeight / Self.representativeImageAspect
            + thicknessFraction * (paneCountAcrossHeight + 1)
        return widthFraction / max(heightFraction, 0.001)
    }

    private var labelBackgroundColor: Color {
        let base = settings.labelBackground.matchBorderColor
            ? settings.border.color
            : settings.labelBackground.color
        return Color(rgba: base).opacity(settings.labelBackground.opacity)
    }

    private var fullWidthAlignment: Alignment {
        switch settings.fullWidthVertical {
            case .top: .top
            case .middle: .center
            case .bottom: .bottom
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let scaleFactor = computeScaleFactor(canvasSize: proxy.size)
            content(scaleFactor: scaleFactor, size: proxy.size)
        }
        .aspectRatio(canvasAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "combine_preview_desc"))
    }

    private func computeScaleFactor(canvasSize: CGSize) -> CGFloat {
        let thickness = settings.border.isEnabled ? CGFloat(settings.border.thickness) : 0
        let thicknessFraction = thickness / Self.referenceImageWidth
        let denom = paneCountAcrossWidth + thicknessFraction * (paneCountAcrossWidth + 1)
        let paneWidth = canvasSize.width / max(denom, 0.001)
        return max(paneWidth / Self.referenceImageWidth, 0.1)
    }

    @ViewBuilder
    private func content(scaleFactor: CGFloat, size: CGSize) -> some View {
        let borderPx = settings.border.isEnabled
            ? CGFloat(settings.border.thickness) * scaleFactor
            : 0
        let paneHeight = paneHeight(in: size, borderPx: borderPx)
        let borderColor = settings.border.isEnabled
            ? Color(rgba: settings.border.color)
            : Color.clear
        contentStack(scaleFactor: scaleFactor, paneHeight: paneHeight, spacing: borderPx)
            .padding(borderPx)
            .background(borderColor)
    }

    private func paneHeight(in size: CGSize, borderPx: CGFloat) -> CGFloat {
        switch settings.direction {
            case .horizontal:
                max(0, size.height - borderPx * 2)

            case .vertical:
                max(0, (size.height - borderPx * 3) / 2)
        }
    }

    @ViewBuilder
    private func contentStack(scaleFactor: CGFloat, paneHeight: CGFloat, spacing: CGFloat) -> some View {
        switch settings.direction {
            case .horizontal:
                HStack(spacing: spacing) {
                    pane(
                        text: settings.label.beforeText,
                        background: Color.appOnSurfaceVariant.opacity(0.4),
                        position: settings.beforePosition,
                        scaleFactor: scaleFactor,
                        paneHeight: paneHeight,
                    )
                    pane(
                        text: settings.label.afterText,
                        background: Color.appOnSurfaceVariant.opacity(0.6),
                        position: settings.afterPosition,
                        scaleFactor: scaleFactor,
                        paneHeight: paneHeight,
                    )
                }

            case .vertical:
                VStack(spacing: spacing) {
                    pane(
                        text: settings.label.beforeText,
                        background: Color.appOnSurfaceVariant.opacity(0.4),
                        position: settings.beforePosition,
                        scaleFactor: scaleFactor,
                        paneHeight: paneHeight,
                    )
                    pane(
                        text: settings.label.afterText,
                        background: Color.appOnSurfaceVariant.opacity(0.6),
                        position: settings.afterPosition,
                        scaleFactor: scaleFactor,
                        paneHeight: paneHeight,
                    )
                }
        }
    }

    private func pane(
        text: String,
        background: Color,
        position: CombineSettings.LabelPosition,
        scaleFactor: CGFloat,
        paneHeight: CGFloat,
    ) -> some View {
        let fontSize = computedFontSize(scaleFactor: scaleFactor, paneHeight: paneHeight)
        let isFree = settings.labelMode == .free
        let margin = fontSize * 0.4
        return ZStack {
            background
            if settings.label.isEnabled {
                labelView(text: text, fontSize: fontSize, scaleFactor: scaleFactor, isFree: isFree)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: isFree ? alignment(for: position) : fullWidthAlignment,
                    )
                    .padding(isFree ? margin : 0)
            }
        }
    }

    private func computedFontSize(scaleFactor: CGFloat, paneHeight: CGFloat) -> CGFloat {
        let scaledMinFontSize: CGFloat = 10 * scaleFactor
        let percentFontSize = CGFloat(settings.label.textSizePercent) * 0.01 * paneHeight
        return max(scaledMinFontSize, percentFontSize)
    }

    @ViewBuilder
    private func labelView(text: String, fontSize: CGFloat, scaleFactor: CGFloat, isFree: Bool) -> some View {
        let rectHeight = fontSize * 1.6
        let hPad = fontSize * 0.75
        let scaledCornerRadius = CGFloat(settings.labelBackground.cornerRadius) * scaleFactor

        let textView = Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(Color(rgba: settings.label.textColor))
            .lineLimit(1)

        if settings.labelBackground.isEnabled {
            textView
                .padding(.horizontal, hPad)
                .frame(maxWidth: isFree ? nil : .infinity)
                .frame(height: rectHeight)
                .background(
                    RoundedRectangle(
                        cornerRadius: isFree ? scaledCornerRadius : 0,
                        style: .continuous,
                    )
                    .fill(labelBackgroundColor),
                )
        } else {
            textView.frame(height: rectHeight)
        }
    }

    private func alignment(for position: CombineSettings.LabelPosition) -> Alignment {
        let horizontal: HorizontalAlignment =
            switch position.horizontal {
                case .leading:
                    .leading

                case .center:
                    .center

                case .trailing:
                    .trailing
            }
        let vertical: VerticalAlignment =
            switch position.vertical {
                case .top:
                    .top

                case .middle:
                    .center

                case .bottom:
                    .bottom
            }
        return Alignment(horizontal: horizontal, vertical: vertical)
    }
}

#Preview {
    Form {
        Section {
            CombinePreviewCard(settings: .default)
        }
    }
}
