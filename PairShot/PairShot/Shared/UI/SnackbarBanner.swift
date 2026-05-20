import SwiftUI

struct SnackbarBanner: View {
    let item: SnackbarItem
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: item.iconSymbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(item.body)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            if case let .progress(value, processed, total) = item.variant {
                progressRow(value: value, processed: processed, total: total)
            } else if case .indeterminateProgress = item.variant {
                indeterminateProgressRow
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, item.isProgress ? 20 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveGlass(
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            kind: .regular,
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 3)
        .padding(.horizontal, 12)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {}
        .offset(y: dragOffset)
        .gesture(item.isProgress ? nil : swipeDismissGesture)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .modifier(CloseAccessibilityActionModifier(isProgress: item.isProgress, onDismiss: onDismiss))
    }

    private var swipeDismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if value.translation.height < 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height < -40 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
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

    private var indeterminateProgressRow: some View {
        HStack(alignment: .center, spacing: 10) {
            ProgressView()
                .progressViewStyle(.linear)
                .tint(accentColor)
                .frame(height: 6)
        }
    }

    private func progressRow(value: Double, processed: Int?, total: Int?) -> some View {
        let clamped = max(0, min(1, value))
        return HStack(alignment: .center, spacing: 10) {
            ProgressView(value: clamped, total: 1.0)
                .progressViewStyle(.linear)
                .tint(accentColor)
                .frame(height: 6)
                .animation(.easeOut(duration: 0.25), value: clamped)
            progressLabel(clamped: clamped, processed: processed, total: total)
        }
    }

    @ViewBuilder
    private func progressLabel(clamped: Double, processed: Int?, total: Int?) -> some View {
        let percentText = String(format: "%d %%", Int(clamped * 100))
        if let processed, let total {
            HStack(spacing: 4) {
                Text("\(processed) / \(total)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(percentText)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .frame(minWidth: 54, alignment: .trailing)
        } else {
            Text(percentText)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(minWidth: 54, alignment: .trailing)
        }
    }
}

private struct CloseAccessibilityActionModifier: ViewModifier {
    let isProgress: Bool
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        if isProgress {
            content
        } else {
            content.accessibilityAction(named: Text(String(localized: "common_button_close"))) {
                onDismiss()
            }
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
