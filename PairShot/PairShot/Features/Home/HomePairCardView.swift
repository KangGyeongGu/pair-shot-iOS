import SwiftUI
import UIKit

struct HomePairCardView: View {
    let pair: PhotoPair
    let storage: PhotoStorageService
    let isSelectionMode: Bool
    let isSelected: Bool

    var body: some View {
        Color.clear
            .aspectRatio(1.8, contentMode: .fit)
            .overlay { splitContainer }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) { topTrailingBadge }
            .overlay(borderOverlay)
            .overlay(selectionTint)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.accessibilityLabel(
                for: pair,
                isSelected: isSelected,
                isSelectionMode: isSelectionMode
            ))
    }

    @ViewBuilder
    private var topTrailingBadge: some View {
        if isSelectionMode {
            selectionMarker.padding(8)
        } else if pair.status == .combined {
            combinedIndicator.padding(8)
        }
    }

    static func accessibilityLabel(
        for pair: PhotoPair,
        isSelected: Bool,
        isSelectionMode: Bool
    ) -> String {
        let statusText = statusLabel(for: pair)
        let selectionText: String? = isSelectionMode
            ? (isSelected ? String(localized: "common_state_selected") : String(localized: "common_state_unselected"))
            : nil
        return [statusText, selectionText]
            .compactMap(\.self)
            .joined(separator: ", ")
    }

    private var splitContainer: some View {
        HStack(spacing: 0) {
            HomePairCardSide(
                source: .init(kind: .before, fileName: pair.beforeFileName),
                storage: storage,
                placeholder: .image
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.5))
                .frame(width: 1)

            afterSide
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var afterSide: some View {
        if let afterName = pair.afterFileName {
            HomePairCardSide(
                source: .init(kind: .after, fileName: afterName),
                storage: storage,
                placeholder: .image
            )
        } else {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                Image(systemName: "camera.fill")
                    .font(.title.weight(.light))
                    .foregroundStyle(.secondary.opacity(0.4))
            }
        }
    }

    private var combinedIndicator: some View {
        Image(systemName: "square.on.square")
            .font(.appCaptionBold)
            .foregroundStyle(Color.white)
            .frame(width: 28, height: 28)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private var selectionMarker: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.accentColor : .white)
            .background(Circle().fill(.black.opacity(0.35)))
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
                isSelected ? Color.accentColor : Color(uiColor: .separator).opacity(0.6),
                lineWidth: isSelected ? 2 : 1
            )
    }

    @ViewBuilder
    private var selectionTint: some View {
        if isSelectionMode, isSelected {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.15))
                .allowsHitTesting(false)
        }
    }

    private static func statusLabel(for pair: PhotoPair) -> String {
        switch pair.status {
            case .scheduled: String(localized: "pair_card_desc_scheduled")
            case .captured: String(localized: "pair_card_desc_captured")
            case .combined: String(localized: "pair_card_desc_combined")
        }
    }
}

private struct HomePairCardSide: View {
    enum Placeholder {
        case image
        case empty
    }

    let source: AlbumCoverSource
    let storage: PhotoStorageService
    let placeholder: Placeholder

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else if case .image = placeholder {
                Image(systemName: "photo")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task(id: cacheToken) { await load() }
    }

    private var cacheToken: String {
        "\(source.kind.rawValue)/\(source.fileName)"
    }

    private func load() async {
        let kind = source.kind
        let fileName = source.fileName
        if let cached = ThumbnailCache.shared.cached(kind: kind, fileName: fileName) {
            thumbnail = cached
            return
        }
        let storage = storage
        let decoded = await Task.detached(priority: .userInitiated) {
            ThumbnailCache.shared.loadThumbnail(kind: kind, fileName: fileName, storage: storage)
        }.value
        thumbnail = decoded
    }
}
