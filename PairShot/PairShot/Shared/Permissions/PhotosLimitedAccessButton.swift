import Photos
import PhotosUI
import SwiftUI
import UIKit

struct PhotosLimitedAccessButton: View {
    @State private var status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        Group {
            if status == .limited {
                Button {
                    presentLimitedLibraryPicker()
                } label: {
                    Label(
                        String(localized: "photos_add_more"),
                        systemImage: "photo.badge.plus"
                    )
                }
            }
        }
        .onAppear { refreshStatus() }
    }

    private func refreshStatus() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
            let viewController = topViewController(in: scene) else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
    }

    private func topViewController(in scene: UIWindowScene) -> UIViewController? {
        guard let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene.windows.first?.rootViewController else { return nil }
        var current = root
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }
}
