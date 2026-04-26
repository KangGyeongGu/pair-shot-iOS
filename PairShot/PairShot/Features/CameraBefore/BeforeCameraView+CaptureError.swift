@preconcurrency import AVFoundation
import SwiftUI

/// Audit-C — capture-error alert + Korean error-text helpers + camera
/// authorization probe split out of ``BeforeCameraView`` so the parent
/// stays under the 250-line cap (`.claude/refs/swiftui-patterns.md`).
/// Pure presentation; no `CameraSession` actor reach-back.
extension BeforeCameraView {
    /// Probe the camera authorization status, requesting access on
    /// `.notDetermined`. Same shape as the After flow so the two view
    /// implementations stay in lock-step.
    static func resolveCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                true

            case .notDetermined:
                await AVCaptureDevice.requestAccess(for: .video)

            case .denied, .restricted:
                false

            @unknown default:
                false
        }
    }

    /// `Bool` binding for the `.alert` modifier driven by the parent's
    /// `captureErrorMessage` state.
    func makeCaptureErrorBinding(
        getMessage: @escaping () -> String?,
        clear: @escaping () -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { getMessage() != nil },
            set: { if !$0 { clear() } }
        )
    }

    /// Translate a ``CaptureActionError`` into a Korean alert message.
    /// We deliberately don't surface the underlying error description
    /// (often AVFoundation jargon) — the user only needs to know
    /// whether to retry or open Settings.
    static func captureErrorText(for error: Error) -> String {
        guard let captureError = error as? CaptureActionError else {
            return String(localized: "촬영을 완료할 수 없습니다. 잠시 후 다시 시도해 주세요.")
        }
        return switch captureError {
            case .session: String(localized: "카메라에서 사진을 가져올 수 없습니다. 다시 시도해 주세요.")
            case .storage: String(localized: "사진을 저장할 공간이 부족합니다.")
            case .persistence: String(localized: "사진 정보를 저장하지 못했습니다. 다시 시도해 주세요.")
        }
    }
}

/// Reusable shutter-failure alert. The view modifier surface keeps the
/// boilerplate (title · presenting binding · OK button) out of every
/// camera view body.
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
    /// Apply the shared shutter-failure alert (Audit-C) to a camera view.
    func captureErrorAlert(message: Binding<String?>) -> some View {
        modifier(CaptureErrorAlert(message: message))
    }
}
