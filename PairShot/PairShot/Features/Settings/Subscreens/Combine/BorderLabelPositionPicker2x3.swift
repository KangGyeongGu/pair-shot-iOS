import SwiftUI

struct BorderLabelPositionPicker2x3: View {
    private static let positions: [(
        CombineSettings.LabelPosition.Horizontal,
        CombineSettings.BorderLabelPosition.Vertical
    )] = [
        (.leading, .top),
        (.center, .top),
        (.trailing, .top),
        (.leading, .bottom),
        (.center, .bottom),
        (.trailing, .bottom),
    ]

    private static let cellSide: CGFloat = 24
    private static let cellGap: CGFloat = 4

    let label: String
    @Binding var selection: CombineSettings.BorderLabelPosition

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: Self.cellGap) {
                ForEach(0 ..< 2, id: \.self) { row in
                    HStack(spacing: Self.cellGap) {
                        ForEach(0 ..< 3, id: \.self) { col in
                            cell(at: row, col: col)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func cell(at row: Int, col: Int) -> some View {
        let index = row * 3 + col
        let position = Self.positions[index]
        let isSelected = selection.horizontal == position.0 && selection.vertical == position.1

        Button {
            selection = CombineSettings.BorderLabelPosition(
                horizontal: position.0,
                vertical: position.1,
            )
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                    .frame(width: Self.cellSide, height: Self.cellSide)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.appCaptionBold)
                        .foregroundStyle(Color.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(horizontal: position.0, vertical: position.1))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityLabel(
        horizontal: CombineSettings.LabelPosition.Horizontal,
        vertical: CombineSettings.BorderLabelPosition.Vertical,
    ) -> String {
        "\(verticalText(vertical)) \(horizontalText(horizontal))"
    }

    private func horizontalText(_ value: CombineSettings.LabelPosition.Horizontal) -> String {
        switch value {
            case .leading:
                String(localized: "combine_position_left")

            case .center:
                String(localized: "combine_position_center")

            case .trailing:
                String(localized: "combine_position_right")
        }
    }

    private func verticalText(_ value: CombineSettings.BorderLabelPosition.Vertical) -> String {
        switch value {
            case .top:
                String(localized: "combine_position_top")

            case .bottom:
                String(localized: "combine_position_bottom")
        }
    }
}

private struct BorderLabelPositionPicker2x3PreviewWrapper: View {
    @State private var selection = CombineSettings.BorderLabelPosition(
        horizontal: .leading,
        vertical: .bottom,
    )

    var body: some View {
        Form {
            BorderLabelPositionPicker2x3(
                label: String(localized: "combine_field_position_before"),
                selection: $selection,
            )
        }
    }
}

#Preview {
    BorderLabelPositionPicker2x3PreviewWrapper()
}
