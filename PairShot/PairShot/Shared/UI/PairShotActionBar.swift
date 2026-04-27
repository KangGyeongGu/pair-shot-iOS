import SwiftUI

struct PairShotActionItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let isEnabled: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
        self.action = action
    }
}

struct PairShotActionBar: View {
    let items: [PairShotActionItem]

    var body: some View {
        HStack(spacing: 32) {
            ForEach(items) { item in
                actionColumn(item)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .padding(.horizontal, 20)
        .background(.regularMaterial)
    }

    private func actionColumn(_ item: PairShotActionItem) -> some View {
        Button(role: item.role, action: item.action) {
            VStack(spacing: -6) {
                Image(systemName: item.systemImage)
                    .font(.title3)
                Text(item.title)
                    .font(.appLabel)
            }
            .frame(maxWidth: .infinity)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(item.role == .destructive ? Color.appSnackbarError : Color.primary)
        .opacity(item.isEnabled ? 1 : 0.38)
        .disabled(!item.isEnabled)
        .accessibilityLabel(item.title)
    }
}
