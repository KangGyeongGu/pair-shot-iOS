import SwiftUI

struct CombinePreviewCard: View {
    static let referenceImageWidth: CGFloat = 1024
    private static let representativeImageAspect: CGFloat = 4.0 / 3.0

    let settings: CombineSettings

    private var edgeFractions: EdgeBorderFractions {
        EdgeBorderFractions.compute(
            for: settings,
            referenceImageWidth: Self.referenceImageWidth,
            representativeImageAspect: Self.representativeImageAspect,
        )
    }

    private var canvasAspectRatio: CGFloat {
        let fractions = edgeFractions
        let paneW: CGFloat = 1
        let paneH = paneW / Self.representativeImageAspect
        let widthFraction: CGFloat
        let heightFraction: CGFloat
        switch settings.direction {
            case .horizontal:
                widthFraction = fractions.left + paneW + fractions.middle + paneW + fractions.right
                heightFraction = fractions.top + paneH + fractions.bottom

            case .vertical:
                widthFraction = fractions.left + paneW + fractions.right
                heightFraction = fractions.top + paneH + fractions.middle + paneH + fractions.bottom
        }
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
        let fractions = edgeFractions
        let paneW: CGFloat = 1
        let widthFraction: CGFloat =
            switch settings.direction {
                case .horizontal: fractions.left + paneW + fractions.middle + paneW + fractions.right
                case .vertical: fractions.left + paneW + fractions.right
            }
        let paneWidthPx = canvasSize.width / max(widthFraction, 0.001)
        return max(paneWidthPx / Self.referenceImageWidth, 0.1)
    }

    @ViewBuilder
    private func content(scaleFactor: CGFloat, size: CGSize) -> some View {
        let fractions = edgeFractions
        let edgesPx = EdgeBordersPx(
            top: fractions.top * Self.referenceImageWidth * scaleFactor,
            bottom: fractions.bottom * Self.referenceImageWidth * scaleFactor,
            left: fractions.left * Self.referenceImageWidth * scaleFactor,
            right: fractions.right * Self.referenceImageWidth * scaleFactor,
            middle: fractions.middle * Self.referenceImageWidth * scaleFactor,
        )
        let paneHeight = paneHeight(in: size, edges: edgesPx)
        let paneWidth = paneWidth(in: size, edges: edgesPx)
        let borderColor = settings.border.isEnabled
            ? Color(rgba: settings.border.color)
            : Color.clear

        ZStack(alignment: .topLeading) {
            borderColor
            contentStack(scaleFactor: scaleFactor, paneHeight: paneHeight, edges: edgesPx)
                .padding(.top, edgesPx.top)
                .padding(.bottom, edgesPx.bottom)
                .padding(.leading, edgesPx.left)
                .padding(.trailing, edgesPx.right)
            if settings.label.isEnabled, settings.labelPlacement == .border {
                borderLabelOverlay(
                    edges: edgesPx,
                    paneWidth: paneWidth,
                    paneHeight: paneHeight,
                    scaleFactor: scaleFactor,
                    canvasSize: size,
                )
            }
        }
    }

    private func paneHeight(in size: CGSize, edges: EdgeBordersPx) -> CGFloat {
        switch settings.direction {
            case .horizontal:
                max(0, size.height - edges.top - edges.bottom)

            case .vertical:
                max(0, (size.height - edges.top - edges.middle - edges.bottom) / 2)
        }
    }

    private func paneWidth(in size: CGSize, edges: EdgeBordersPx) -> CGFloat {
        switch settings.direction {
            case .horizontal:
                max(0, (size.width - edges.left - edges.middle - edges.right) / 2)

            case .vertical:
                max(0, size.width - edges.left - edges.right)
        }
    }

    @ViewBuilder
    private func contentStack(scaleFactor: CGFloat, paneHeight: CGFloat, edges: EdgeBordersPx) -> some View {
        switch settings.direction {
            case .horizontal:
                HStack(spacing: edges.middle) {
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
                VStack(spacing: edges.middle) {
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
        let showImageLabel = settings.label.isEnabled && settings.labelPlacement == .image
        return ZStack {
            background
            if showImageLabel {
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

private extension CombinePreviewCard {
    @ViewBuilder
    func borderLabelOverlay(
        edges: EdgeBordersPx,
        paneWidth: CGFloat,
        paneHeight: CGFloat,
        scaleFactor: CGFloat,
        canvasSize: CGSize,
    ) -> some View {
        let fontSize = computedFontSize(scaleFactor: scaleFactor, paneHeight: paneHeight)
        let beforeRect = borderStripCanvasRect(
            position: settings.beforeBorderPosition,
            edges: edges,
            paneWidth: paneWidth,
            paneHeight: paneHeight,
            canvasSize: canvasSize,
            isBefore: true,
        )
        let afterRect = borderStripCanvasRect(
            position: settings.afterBorderPosition,
            edges: edges,
            paneWidth: paneWidth,
            paneHeight: paneHeight,
            canvasSize: canvasSize,
            isBefore: false,
        )
        ZStack(alignment: .topLeading) {
            borderStripLabel(
                rect: beforeRect,
                text: settings.label.beforeText,
                horizontal: settings.beforeBorderPosition.horizontal,
                fontSize: fontSize,
            )
            borderStripLabel(
                rect: afterRect,
                text: settings.label.afterText,
                horizontal: settings.afterBorderPosition.horizontal,
                fontSize: fontSize,
            )
        }
    }

    func borderStripCanvasRect(
        position: CombineSettings.BorderLabelPosition,
        edges: EdgeBordersPx,
        paneWidth: CGFloat,
        paneHeight: CGFloat,
        canvasSize: CGSize,
        isBefore: Bool,
    ) -> CGRect {
        switch settings.direction {
            case .horizontal:
                horizontalBorderStrip(
                    position: position,
                    edges: edges,
                    paneWidth: paneWidth,
                    canvasSize: canvasSize,
                    isBefore: isBefore,
                )

            case .vertical:
                verticalBorderStrip(
                    position: position,
                    edges: edges,
                    paneWidth: paneWidth,
                    paneHeight: paneHeight,
                    canvasSize: canvasSize,
                    isBefore: isBefore,
                )
        }
    }

    func horizontalBorderStrip(
        position: CombineSettings.BorderLabelPosition,
        edges: EdgeBordersPx,
        paneWidth: CGFloat,
        canvasSize: CGSize,
        isBefore: Bool,
    ) -> CGRect {
        let xOffset = isBefore ? edges.left : edges.left + paneWidth + edges.middle
        switch position.vertical {
            case .top:
                return CGRect(x: xOffset, y: 0, width: paneWidth, height: edges.top)

            case .bottom:
                return CGRect(
                    x: xOffset,
                    y: canvasSize.height - edges.bottom,
                    width: paneWidth,
                    height: edges.bottom,
                )
        }
    }

    func verticalBorderStrip(
        position: CombineSettings.BorderLabelPosition,
        edges: EdgeBordersPx,
        paneWidth: CGFloat,
        paneHeight: CGFloat,
        canvasSize: CGSize,
        isBefore: Bool,
    ) -> CGRect {
        let paneTop = isBefore ? edges.top : edges.top + paneHeight + edges.middle
        let paneBottom = paneTop + paneHeight
        switch position.vertical {
            case .top:
                let stripHeight = isBefore ? edges.top : edges.middle
                let stripY = isBefore ? 0 : paneTop - edges.middle
                return CGRect(x: edges.left, y: stripY, width: paneWidth, height: stripHeight)

            case .bottom:
                let stripHeight = isBefore ? edges.middle : edges.bottom
                let stripY = isBefore ? paneBottom : canvasSize.height - edges.bottom
                return CGRect(x: edges.left, y: stripY, width: paneWidth, height: stripHeight)
        }
    }

    @ViewBuilder
    func borderStripLabel(
        rect: CGRect,
        text: String,
        horizontal: CombineSettings.LabelPosition.Horizontal,
        fontSize: CGFloat,
    ) -> some View {
        let stripBackground = settings.labelBackground.matchBorderColor
            ? Color.clear
            : labelBackgroundColor
        let alignment: Alignment =
            switch horizontal {
                case .leading: .leading
                case .center: .center
                case .trailing: .trailing
            }
        let hPad = fontSize * 0.75
        ZStack(alignment: alignment) {
            stripBackground
            Text(text)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(Color(rgba: settings.label.textColor))
                .lineLimit(1)
                .padding(.horizontal, hPad)
        }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
    }
}

#Preview {
    Form {
        Section {
            CombinePreviewCard(settings: .default)
        }
    }
}
