import SwiftUI

/// Audit-C — capture-error alert + ghost-warning toast helpers split
/// out of ``AfterCameraView`` so the parent stays under the 250-line
/// cap (`.claude/refs/swiftui-patterns.md`). Pure presentation; no
/// AVFoundation reach-back.
extension AfterCameraView {
    /// Translate an ``AfterCaptureActionError`` into a Korean alert
    /// message. Mirrors ``BeforeCameraView/captureErrorText(for:)`` so
    /// users get the same vocabulary across both capture flows.
    static func afterCaptureErrorText(for error: Error) -> String {
        guard let captureError = error as? AfterCaptureActionError else {
            return String(localized: "촬영을 완료할 수 없습니다. 잠시 후 다시 시도해 주세요.")
        }
        return switch captureError {
            case .session: String(localized: "카메라에서 사진을 가져올 수 없습니다. 다시 시도해 주세요.")
            case .storage: String(localized: "사진을 저장할 공간이 부족합니다.")
            case .persistence: String(localized: "사진 정보를 저장하지 못했습니다. 다시 시도해 주세요.")
            case .alreadyComplete: String(localized: "이미 완료된 페어입니다.")
        }
    }
}

/// Reusable transient toast for stale-ghost / status messages on the
/// After camera. Auto-dismisses after 2 seconds.
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
    /// Apply the After-camera transient toast (Audit-C — stale Before
    /// file warning).
    func ghostWarningToast(message: Binding<String?>) -> some View {
        modifier(GhostWarningToast(message: message))
    }
}
