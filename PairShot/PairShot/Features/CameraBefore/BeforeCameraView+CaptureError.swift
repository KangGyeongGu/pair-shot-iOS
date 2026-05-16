import SwiftUI

struct CaptureErrorAlert: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "camera_error_capture_title"),
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } },
            ),
            presenting: message,
        ) { _ in
            Button(String(localized: "common_button_confirm"), role: .cancel) { message = nil }
        } message: { text in
            Text(text)
        }
    }
}

extension View {
    func captureErrorAlert(message: Binding<String?>) -> some View {
        modifier(CaptureErrorAlert(message: message))
    }
}
