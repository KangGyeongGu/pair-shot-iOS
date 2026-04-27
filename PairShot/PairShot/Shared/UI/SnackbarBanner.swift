import SwiftUI

struct SnackbarBanner: View {
    let item: SnackbarItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
            Text(item.message)
                .font(.body)
                .foregroundStyle(.white)
                .lineLimit(3)
            Spacer(minLength: 0)
            if item.isActionable {
                Button {
                    onDismiss()
                } label: {
                    Text(String(localized: "common_button_close"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private var iconName: String {
        switch item.variant {
            case .success:
                "checkmark.circle.fill"

            case .error:
                "xmark.octagon.fill"

            case .warning:
                "exclamationmark.triangle.fill"

            case .info:
                "info.circle.fill"
        }
    }

    private var backgroundColor: Color {
        switch item.variant {
            case .success:
                Color.appSnackbarSuccess.opacity(0.92)

            case .error:
                Color.appSnackbarError.opacity(0.92)

            case .warning:
                Color.appSnackbarWarning.opacity(0.92)

            case .info:
                Color.appSnackbarInfo.opacity(0.92)
        }
    }
}

private struct SnackbarOverlayModifier: ViewModifier {
    @Bindable var queue: SnackbarQueue

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let current = queue.current {
                SnackbarBanner(item: current) {
                    queue.dismiss()
                }
                .id(current.id)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: queue.current?.id)
    }
}

extension View {
    func snackbarOverlay(_ queue: SnackbarQueue) -> some View {
        modifier(SnackbarOverlayModifier(queue: queue))
    }
}
