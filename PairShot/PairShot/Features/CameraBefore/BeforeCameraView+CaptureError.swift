import SwiftUI

struct CaptureErrorAlert: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "촬영 실패"),
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            ),
            presenting: message
        ) { _ in
            Button(String(localized: "확인"), role: .cancel) { message = nil }
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
