import SwiftUI

struct HomePairSelectionBottomBar: View {
    let selectionCount: Int
    let onShare: () -> Void
    let onSaveToDevice: () -> Void
    let onDelete: () -> Void
    let onExportSettings: () -> Void

    var body: some View {
        let enabled = selectionCount > 0
        HStack(spacing: 8) {
            actionColumn(
                title: String(localized: "common_button_share"),
                systemImage: "square.and.arrow.up",
                isEnabled: enabled,
                role: nil,
                action: onShare
            )
            actionColumn(
                title: String(localized: "common_button_save_to_device"),
                systemImage: "arrow.down.to.line",
                isEnabled: enabled,
                role: nil,
                action: onSaveToDevice
            )
            actionColumn(
                title: String(localized: "common_button_delete"),
                systemImage: "trash",
                isEnabled: enabled,
                role: .destructive,
                action: onDelete
            )
            actionColumn(
                title: String(localized: "common_button_export"),
                systemImage: "slider.horizontal.3",
                isEnabled: enabled,
                role: nil,
                action: onExportSettings
            )
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 60)
        .adaptiveGlass(in: Capsule(style: .continuous), kind: .regular)
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 3)
    }

    private func actionColumn(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        role: ButtonRole?,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(height: 24)
                Text(title)
                    .font(.appLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.appSnackbarError : Color.primary)
        .opacity(isEnabled ? 1 : 0.38)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}
