import SwiftUI

struct GhostWarningToast: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 110)
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        self.message = nil
                    }
            }
        }
    }
}

extension View {
    func ghostWarningToast(message: Binding<String?>) -> some View {
        modifier(GhostWarningToast(message: message))
    }
}
