import SwiftUI
import UIKit

/// P9.4 — Reusable empty/error view for permission-denied states.
///
/// Wraps `ContentUnavailableView` with a "설정으로 이동" button that
/// deep-links to the app's Settings page so the user can flip the
/// permission switch without leaving the app for the home screen.
///
/// Two convenience initialisers cover the common cases:
/// - ``init(forCamera:)`` — camera (AVFoundation) authorization denied.
/// - ``init(forPhotoLibrary:)`` — photo library write authorization
///   denied (`PHPhotoLibrary` `.addOnly`).
///
/// Both initialisers route to a shared `PermissionDeniedSettingsURL`
/// pure-helper so the URL construction can be tested without UIKit.
struct PermissionDeniedView: View {
    let title: String
    let message: String
    let systemImage: String

    /// Injectable for tests. Defaults to UIKit's
    /// `openSettingsURLString`-based opener.
    private let opener: @MainActor () -> Void

    init(
        title: String,
        message: String,
        systemImage: String = "exclamationmark.triangle.fill",
        opener: @MainActor @escaping () -> Void = PermissionDeniedSettingsURL.openSystemSettings
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.opener = opener
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            Button {
                opener()
            } label: {
                Text(String(localized: "설정으로 이동"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

extension PermissionDeniedView {
    /// Convenience for camera-permission denials. Used by Before/After
    /// camera screens and the QR scanner. The unused `Void`
    /// parameter exists purely as an external label so the call site
    /// reads `PermissionDeniedView(forCamera: ())`.
    init(
        forCamera _: Void,
        opener: @MainActor @escaping () -> Void = PermissionDeniedSettingsURL.openSystemSettings
    ) {
        self.init(
            title: String(localized: "카메라 권한이 필요합니다"),
            message: String(localized: "설정에서 카메라 사용을 허용해 주세요"),
            systemImage: "camera.metering.unknown",
            opener: opener
        )
    }

    /// Convenience for photo-library write denials. Used by the
    /// Photos export path when `PHAuthorizationStatus` is `.denied`.
    init(
        forPhotoLibrary _: Void,
        opener: @MainActor @escaping () -> Void = PermissionDeniedSettingsURL.openSystemSettings
    ) {
        self.init(
            title: String(localized: "사진 라이브러리 권한이 필요합니다"),
            message: String(localized: "설정에서 사진 저장을 허용해 주세요"),
            systemImage: "photo.badge.exclamationmark",
            opener: opener
        )
    }
}

/// Pure helper for the Settings deep-link. Extracted so the URL
/// construction is exercised by ``PermissionDeniedViewTests`` without
/// driving UIKit / SwiftUI.
enum PermissionDeniedSettingsURL {
    /// The Settings deep-link URL. Returns `nil` only if Apple ever
    /// changes `UIApplication.openSettingsURLString` to something
    /// that isn't a valid URL — currently impossible but defensively
    /// optional so the call site can no-op gracefully.
    static func makeURL() -> URL? {
        URL(string: UIApplication.openSettingsURLString)
    }

    /// Production opener — called from the button's action by default.
    @MainActor
    static func openSystemSettings() {
        guard let url = makeURL() else { return }
        UIApplication.shared.open(url)
    }
}

#Preview("Camera denied") {
    PermissionDeniedView(forCamera: ())
}

#Preview("Photo library denied") {
    PermissionDeniedView(forPhotoLibrary: ())
}
