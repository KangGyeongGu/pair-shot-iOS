import SwiftUI
import UIKit

struct StripCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.displayScale) private var displayScale

    let pair: PhotoPair
    let isActive: Bool
    let stripZoneHeight: CGFloat

    @State private var thumbnail: UIImage?

    private var cardWidth: CGFloat {
        StripDesign.cardWidth(stripHeight: stripZoneHeight)
    }

    private var cardHeight: CGFloat {
        StripDesign.cardHeight(stripHeight: stripZoneHeight)
    }

    private var cornerRadius: CGFloat {
        StripDesign.cornerRadius(stripHeight: stripZoneHeight)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
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
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
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
        guard let identifier = pair.beforePhotoLocalIdentifier, !identifier.isEmpty else { return }
        let scale = max(1, displayScale)
        thumbnail = await env.thumbnailCache.image(
            for: identifier,
            pixelSize: cardWidth * scale
        )
    }
}
