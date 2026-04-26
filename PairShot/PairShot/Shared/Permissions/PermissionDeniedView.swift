import SwiftUI
import UIKit

struct PermissionDeniedView: View {
    let title: String
    let message: String
    let systemImage: String

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
