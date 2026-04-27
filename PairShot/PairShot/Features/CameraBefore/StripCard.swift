import SwiftUI
import UIKit

struct StripCard: View {
    let pair: PhotoPair
    let storage: PhotoStorageService
    let isActive: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: StripDesign.cardCornerRadius)
                .fill(Color.white.opacity(0.06))

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(width: StripDesign.cardWidth, height: StripDesign.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: StripDesign.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StripDesign.cardCornerRadius)
                .stroke(
                    isActive ? StripDesign.activeBorderColor : StripDesign.inactiveBorderColor,
                    lineWidth: isActive ? StripDesign.activeBorderWidth : StripDesign.inactiveBorderWidth
                )
        )
        .scaleEffect(isActive ? StripDesign.activeScale : StripDesign.inactiveScale, anchor: .center)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .task(id: pair.id) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let fileName = pair.beforeFileName
        let storageRef = storage
        let image = await Task.detached(priority: .userInitiated) {
            ThumbnailCache.shared.loadThumbnail(
                kind: .before,
                fileName: fileName,
                storage: storageRef
            )
        }.value
        thumbnail = image
    }
}
