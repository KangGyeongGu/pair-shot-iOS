import SwiftUI
import UIKit

struct PermissionDeniedView: View {
    let title: String
    let message: String
    let systemImage: String

    private let opener: @MainActor () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            Button {
                opener()
            } label: {
                Text(String(localized: "permission_button_open_settings"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
    }

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
}

extension PermissionDeniedView {
    init(
        forCamera _: Void,
        opener: @MainActor @escaping () -> Void = PermissionDeniedSettingsURL.openSystemSettings
    ) {
        self.init(
            title: String(localized: "permission_camera_title"),
            message: String(localized: "permission_camera_message"),
            systemImage: "camera.metering.unknown",
            opener: opener
        )
    }

    init(
        forPhotoLibrary _: Void,
        opener: @MainActor @escaping () -> Void = PermissionDeniedSettingsURL.openSystemSettings
    ) {
        self.init(
            title: String(localized: "permission_photo_title"),
            message: String(localized: "permission_photo_message"),
            systemImage: "photo.badge.exclamationmark",
            opener: opener
        )
    }
}

enum PermissionDeniedSettingsURL {
    static func makeURL() -> URL? {
        URL(string: UIApplication.openSettingsURLString)
    }

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
