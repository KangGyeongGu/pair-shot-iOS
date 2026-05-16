import SwiftUI

struct CombinePreviewCard: View {
    static let referenceImageWidth: CGFloat = 1024

    let settings: CombineSettings

    var body: some View {
        GeometryReader { proxy in
            let scaleFactor = max(proxy.size.width / Self.referenceImageWidth, 0.1)
            content(scaleFactor: scaleFactor, size: proxy.size)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "combine_preview_desc"))
    }

    private var aspectRatio: CGFloat {
        switch settings.direction {
            case .horizontal:
                2.0

            case .vertical:
                0.5
        }
    }

    private var labelBackgroundColor: Color {
        let base =
            settings.labelBackground.matchBorderColor
                ? settings.border.color
                : settings.labelBackground.color
        return Color(rgba: base).opacity(settings.labelBackground.opacity)
    }

    @ViewBuilder
    private func content(scaleFactor: CGFloat, size: CGSize) -> some View {
        let borderPx =
            settings.border.isEnabled
                ? CGFloat(settings.border.thickness) * scaleFactor
                : 0
        let paneHeight = paneHeight(in: size, borderPx: borderPx)
        let borderColor =
            settings.border.isEnabled
                ? Color(rgba: settings.border.color)
                : Color.clear
        contentStack(scaleFactor: scaleFactor, paneHeight: paneHeight, spacing: borderPx * 2)
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
                VStack(spacing: 0) {
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
        let padding = max(2, 8 * scaleFactor)
        return ZStack {
            background
            if settings.label.isEnabled {
                labelView(text: text, scaleFactor: scaleFactor, paneHeight: paneHeight)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: alignment(for: position),
                    )
                    .padding(padding)
            }
        }
    }

    @ViewBuilder
    private func labelView(text: String, scaleFactor: CGFloat, paneHeight: CGFloat) -> some View {
        let scaledMinFontSize: CGFloat = 10 * scaleFactor
        let percentFontSize = CGFloat(settings.label.textSizePercent) * 0.01 * paneHeight
        let fontSize = max(scaledMinFontSize, percentFontSize)
        let scaledHorizontalPadding = max(1, 6 * scaleFactor)
        let scaledVerticalPadding = max(1, 2 * scaleFactor)
        let scaledCornerRadius = CGFloat(settings.labelBackground.cornerRadius) * scaleFactor

        let textView = Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(Color(rgba: settings.label.textColor))

        if settings.labelBackground.isEnabled {
            textView
                .padding(.horizontal, scaledHorizontalPadding)
                .padding(.vertical, scaledVerticalPadding)
                .background(
                    RoundedRectangle(
                        cornerRadius: settings.labelMode == .free ? scaledCornerRadius : 0,
                        style: .continuous,
                    )
                    .fill(labelBackgroundColor),
                )
        } else {
            textView
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
