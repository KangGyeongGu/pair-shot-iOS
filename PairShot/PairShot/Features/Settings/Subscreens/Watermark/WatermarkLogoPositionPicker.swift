import SwiftUI

struct WatermarkLogoPositionPicker: View {
    private static let layout: [[LogoPosition]] = [
        [.topLeft, .topCenter, .topRight],
        [.centerLeft, .center, .centerRight],
        [.bottomLeft, .bottomCenter, .bottomRight],
    ]

    @Binding var selection: LogoPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "watermark_logo_position"))
            VStack(spacing: 6) {
                ForEach(0 ..< Self.layout.count, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(Self.layout[row], id: \.self) { position in
                            cell(for: position)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cell(for position: LogoPosition) -> some View {
        let isActive = selection == position
        Button {
            selection = position
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.85) : Color.appLetterbox.opacity(0.18))
                    .frame(height: 40)
                Image(systemName: isActive ? "checkmark" : "circle.fill")
                    .font(.system(size: isActive ? 16 : 6, weight: .semibold))
                    .foregroundStyle(isActive ? Color.white : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.accessibilityLabel(for: position))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private static func accessibilityLabel(for position: LogoPosition) -> String {
        switch position {
            case .topLeft: String(localized: "watermark_position_top_left")
            case .topCenter: String(localized: "watermark_position_top_center")
            case .topRight: String(localized: "watermark_position_top_right")
            case .centerLeft: String(localized: "watermark_position_center_left")
            case .center: String(localized: "watermark_position_center")
            case .centerRight: String(localized: "watermark_position_center_right")
            case .bottomLeft: String(localized: "watermark_position_bottom_left")
            case .bottomCenter: String(localized: "watermark_position_bottom_center")
            case .bottomRight: String(localized: "watermark_position_bottom_right")
        }
    }
}
