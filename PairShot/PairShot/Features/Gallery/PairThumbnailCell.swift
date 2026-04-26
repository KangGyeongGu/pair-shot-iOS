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
        // Audit-C — collapse the cell into a single VoiceOver utterance
        // combining status, captured date, and selection state. Without
        // this, every gallery cell read out as "image" only.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(
            for: pair,
            isSelected: isSelected,
            isSelectionMode: isSelectionMode
        ))
        .task(id: pair.beforePath) {
            await loadThumbnail()
        }
    }

    /// Pure helper so the label generation is testable without spinning
    /// up the SwiftUI hierarchy. Returns a Korean utterance like
    /// `"완료 페어, 4월 26일 촬영, 선택됨"`.
    static func accessibilityLabel(
        for pair: PhotoPair,
        isSelected: Bool,
        isSelectionMode: Bool
    ) -> String {
        let statusText = switch pair.status {
            case .pendingAfter: String(localized: "Before 만 촬영된 페어")

            case .complete:
                if let combined = pair.combinedPath, !combined.isEmpty {
                    String(localized: "합성 완료된 페어")
                } else {
                    String(localized: "완료된 페어")
                }
        }
        let dateText = pair.beforeCapturedAt.formatted(.dateTime.month().day())
        let selectionText: String? = isSelectionMode
            ? (isSelected ? String(localized: "선택됨") : String(localized: "선택 안 됨"))
            : nil
        let parts = [statusText, dateText, selectionText].compactMap(\.self)
        return parts.joined(separator: ", ")
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
