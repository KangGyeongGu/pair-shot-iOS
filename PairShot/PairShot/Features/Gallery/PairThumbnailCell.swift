import SwiftUI
import UIKit

/// One grid cell in `PairGalleryView`.
///
/// Extracted from `PairGalleryView` (P6.8 view-size diet) so the parent
/// stays under the 250-line guard. The cell decodes its thumbnail off
/// the main actor via `ThumbnailCache` and renders a status badge plus
/// an optional selection checkmark.
struct PairThumbnailCell: View {
    let pair: PhotoPair
    let storage: PhotoStorageService
    let isSelectionMode: Bool
    let isSelected: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailLayer
                .aspectRatio(1, contentMode: .fit)
                .clipped()
                .background(Color.gray.opacity(0.15))

            statusBadge
                .padding(6)

            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .white)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 3
                )
        )
        .task(id: pair.beforePath) {
            await loadThumbnail()
        }
    }

    @ViewBuilder
    private var thumbnailLayer: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .padding(24)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch pair.status {
            case .pendingAfter:
                badgeText(String(localized: "Before"), tint: .orange)
            case .complete:
                if let combined = pair.combinedPath, !combined.isEmpty {
                    badgeText(String(localized: "합성"), tint: .purple)
                } else {
                    badgeText(String(localized: "완료"), tint: .green)
                }
        }
    }

    private func badgeText(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
    }

    private func loadThumbnail() async {
        if let cached = ThumbnailCache.shared.cached(forRelativePath: pair.beforePath) {
            thumbnail = cached
            return
        }
        let path = pair.beforePath
        let storage = storage
        let decoded = await Task.detached(priority: .userInitiated) {
            ThumbnailCache.shared.loadThumbnail(forRelativePath: path, storage: storage)
        }.value
        thumbnail = decoded
    }
}
