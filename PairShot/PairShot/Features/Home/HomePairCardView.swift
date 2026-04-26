import SwiftUI
import UIKit

struct HomePairCardView: View {
    let pair: PhotoPair
    let storage: PhotoStorageService
    let isSelectionMode: Bool
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            splitContainer
            if pair.status == .combined {
                combinedIndicator
                    .padding(8)
            }
            if isSelectionMode {
                selectionMarker
                    .padding(8)
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(borderOverlay)
        .overlay(selectionTint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(
            for: pair,
            isSelected: isSelected,
            isSelectionMode: isSelectionMode
        ))
    }

    static func accessibilityLabel(
        for pair: PhotoPair,
        isSelected: Bool,
        isSelectionMode: Bool
    ) -> String {
        let statusText = statusLabel(for: pair)
        let selectionText: String? = isSelectionMode
            ? (isSelected ? String(localized: "선택됨") : String(localized: "선택 안 됨"))
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
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.4))
            }
        }
    }

    private var combinedIndicator: some View {
        Image(systemName: "square.on.square")
            .font(.system(size: 14, weight: .semibold))
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
            case .scheduled: String(localized: "Before 만 촬영된 페어")
            case .captured: String(localized: "완료된 페어")
            case .combined: String(localized: "합성 완료된 페어")
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
                    .font(.system(size: 24, weight: .light))
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
