import SwiftUI

struct CombinePositionPicker3x3: View {
    // swiftlint:disable trailing_comma
    private static let positions: [(CombineSettings.LabelPosition.Horizontal, CombineSettings.LabelPosition.Vertical)] =
        [
            (.leading, .top),
            (.center, .top),
            (.trailing, .top),
            (.leading, .middle),
            (.center, .middle),
            (.trailing, .middle),
            (.leading, .bottom),
            (.center, .bottom),
            (.trailing, .bottom),
        ]
    // swiftlint:enable trailing_comma

    private static let cellSide: CGFloat = 24
    private static let cellGap: CGFloat = 4

    let label: String
    @Binding var selection: CombineSettings.LabelPosition

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: Self.cellGap) {
                ForEach(0 ..< 3, id: \.self) { row in
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
            selection = CombineSettings.LabelPosition(
                horizontal: position.0,
                vertical: position.1
            )
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                    .frame(width: Self.cellSide, height: Self.cellSide)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
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
        vertical: CombineSettings.LabelPosition.Vertical
    ) -> String {
        let horizontalText = horizontalLabel(horizontal)
        let verticalText = verticalLabel(vertical)
        return "\(verticalText) \(horizontalText)"
    }

    // swiftlint:disable switch_case_alignment vertical_whitespace_between_cases
    private func horizontalLabel(_ value: CombineSettings.LabelPosition.Horizontal) -> String {
        switch value {
            case .leading:
                String(localized: "왼쪽")
            case .center:
                String(localized: "가운데")
            case .trailing:
                String(localized: "오른쪽")
        }
    }

    private func verticalLabel(_ value: CombineSettings.LabelPosition.Vertical) -> String {
        switch value {
            case .top:
                String(localized: "상단")
            case .middle:
                String(localized: "중단")
            case .bottom:
                String(localized: "하단")
        }
    }
    // swiftlint:enable switch_case_alignment vertical_whitespace_between_cases
}

private struct CombinePositionPicker3x3PreviewWrapper: View {
    @State private var selection = CombineSettings.LabelPosition(horizontal: .leading, vertical: .top)

    var body: some View {
        Form {
            CombinePositionPicker3x3(
                label: String(localized: "Before 위치"),
                selection: $selection
            )
        }
    }
}

#Preview {
    CombinePositionPicker3x3PreviewWrapper()
}
