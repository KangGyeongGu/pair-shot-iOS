import SwiftUI
import UIKit

struct BeforePeekView: View {
    let pair: PhotoPair

    @Environment(AppEnvironment.self) private var env
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var isLoading: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                ZoomableImageView(image: image)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        String(localized: "common_button_close"),
                        systemImage: "xmark",
                    ) {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .task(id: pair.id) {
                await load()
            }
        }
        .presentationBackground(.regularMaterial)
    }

    private func load() async {
        guard let identifier = pair.beforePhotoLocalIdentifier, !identifier.isEmpty else {
            isLoading = false
            return
        }
        let screenBounds = UIScreen.main.bounds.size
        let scale = displayScale
        let targetSize = CGSize(
            width: screenBounds.width * scale,
            height: screenBounds.height * scale,
        )
        isLoading = true
        let loaded = await env.photoLibrary.requestPreviewImage(
            localIdentifier: identifier,
            targetSize: targetSize,
        )
        guard pair.beforePhotoLocalIdentifier == identifier else { return }
        image = loaded
        isLoading = false
    }
}
