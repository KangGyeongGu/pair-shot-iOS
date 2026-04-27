import SwiftUI

struct SnackbarBanner: View {
    let item: SnackbarItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            iconBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(item.message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                if case let .progress(value) = item.variant {
                    ProgressView(value: value, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(accentColor)
                        .padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
            if item.isActionable {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "common_button_close"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SnackbarBannerBackground(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 3)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accentColor)
                .frame(width: 38, height: 38)
            Group {
                switch item.variant {
                    case .progress, .indeterminateProgress:
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .tint(.white)

                    default:
                        Image(systemName: iconName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                }
            }
        }
    }

    private var titleText: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty
        {
            return displayName
        }
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty
        {
            return name
        }
        return "PairShot"
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

            case .progress, .indeterminateProgress:
                "arrow.triangle.2.circlepath"
        }
    }

    private var accentColor: Color {
        switch item.variant {
            case .success:
                Color.appSnackbarSuccess

            case .error:
                Color.appSnackbarError

            case .warning:
                Color.appSnackbarWarning

            case .info, .progress, .indeterminateProgress:
                Color.appSnackbarInfo
        }
    }
}

private struct SnackbarBannerBackground: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(shape.fill(.regularMaterial))
        }
    }
}

private struct SnackbarOverlayModifier: ViewModifier {
    @Bindable var queue: SnackbarQueue

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let current = queue.current {
                SnackbarBanner(item: current) {
                    queue.dismiss()
                }
                .id(current.id)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
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
