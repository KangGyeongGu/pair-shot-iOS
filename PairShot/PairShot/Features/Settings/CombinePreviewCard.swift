import SwiftUI

// swiftlint:disable switch_case_alignment vertical_whitespace_between_cases
struct CombinePreviewCard: View {
    let settings: CombineSettings

    var body: some View {
        contentStack
            .frame(maxWidth: .infinity)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(borderOverlay)
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

    @ViewBuilder
    private var contentStack: some View {
        switch settings.direction {
            case .horizontal:
                HStack(spacing: 0) {
                    pane(
                        text: settings.label.beforeText,
                        background: Color.appOnSurfaceVariant.opacity(0.4),
                        position: settings.beforePosition
                    )
                    pane(
                        text: settings.label.afterText,
                        background: Color.appOnSurfaceVariant.opacity(0.6),
                        position: settings.afterPosition
                    )
                }
            case .vertical:
                VStack(spacing: 0) {
                    pane(
                        text: settings.label.beforeText,
                        background: Color.appOnSurfaceVariant.opacity(0.4),
                        position: settings.beforePosition
                    )
                    pane(
                        text: settings.label.afterText,
                        background: Color.appOnSurfaceVariant.opacity(0.6),
                        position: settings.afterPosition
                    )
                }
        }
    }

    private var labelBackgroundColor: Color {
        let base = settings.labelBackground.matchBorderColor
            ? settings.border.color
            : settings.labelBackground.color
        return Color(rgba: base).opacity(settings.labelBackground.opacity)
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
                settings.border.isEnabled ? Color(rgba: settings.border.color) : Color.clear,
                lineWidth: settings.border.isEnabled ? CGFloat(settings.border.thickness) : 0
            )
    }

    private func pane(
        text: String,
        background: Color,
        position: CombineSettings.LabelPosition
    ) -> some View {
        ZStack {
            background
            if settings.label.isEnabled {
                labelView(text: text)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: alignment(for: position)
                    )
                    .padding(8)
            }
        }
    }

    @ViewBuilder
    private func labelView(text: String) -> some View {
        let fontSize = max(8.0, settings.label.textSizePercent * 2)
        let textView = Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(Color(rgba: settings.label.textColor))

        if settings.labelBackground.isEnabled {
            textView
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(
                        cornerRadius: settings.labelMode == .free
                            ? CGFloat(settings.labelBackground.cornerRadius)
                            : 0,
                        style: .continuous
                    )
                    .fill(labelBackgroundColor)
                )
        } else {
            textView
        }
    }

    private func alignment(for position: CombineSettings.LabelPosition) -> Alignment {
        let horizontal: HorizontalAlignment = switch position.horizontal {
            case .leading:
                .leading
            case .center:
                .center
            case .trailing:
                .trailing
        }
        let vertical: VerticalAlignment = switch position.vertical {
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

// swiftlint:enable switch_case_alignment vertical_whitespace_between_cases

#Preview {
    Form {
        Section {
            CombinePreviewCard(settings: .default)
        }
    }
}
