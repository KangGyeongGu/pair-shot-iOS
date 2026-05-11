import SwiftUI

struct SettingsRowIcon {
    let systemImage: String
    let color: Color
}

struct SettingsIconBadge: View {
    let icon: SettingsRowIcon

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(icon.color)
                .frame(width: 29, height: 29)
            Image(systemName: icon.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }
}

struct SettingsValueRow: View {
    var icon: SettingsRowIcon?
    let title: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                SettingsIconBadge(icon: icon)
            }
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
        }
        .contentShape(Rectangle())
    }
}

struct SettingsNavigationRow: View {
    var icon: SettingsRowIcon?
    let title: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                SettingsIconBadge(icon: icon)
            }
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
