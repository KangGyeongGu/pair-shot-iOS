import SwiftUI
import UIKit

struct HomePairCardView: View {
    let pair: PhotoPair
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
        } else if pair.hasCombinedExport {
            combinedIndicator.padding(8)
        }
    }

    private var combinedIndicator: some View {
        Image(systemName: "square.on.square")
            .font(.appCaptionBold)
            .foregroundStyle(Color.white)
            .frame(width: 28, height: 28)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
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
            beforeSide
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.5))
                .frame(width: 1)

            afterSide
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var beforeSide: some View {
        if let identifier = pair.beforePhotoLocalIdentifier, !identifier.isEmpty {
            HomePairCardSide(
                localIdentifier: identifier,
                placeholder: .image
            )
        } else {
            HomePairCardEmptySlot()
        }
    }

    @ViewBuilder
    private var afterSide: some View {
        if let identifier = pair.afterPhotoLocalIdentifier, !identifier.isEmpty {
            HomePairCardSide(
                localIdentifier: identifier,
                placeholder: .image
            )
        } else {
            HomePairCardEmptySlot()
        }
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
            case .afterOnly: String(localized: "pair_card_desc_captured")
            case .captured: String(localized: "pair_card_desc_captured")
        }
    }
}

private struct HomePairCardEmptySlot: View {
    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            Image(systemName: "camera.fill")
                .font(.title.weight(.light))
                .foregroundStyle(.secondary.opacity(0.4))
        }
    }
}

private struct HomePairCardSide: View {
    enum Placeholder {
        case image
        case empty
    }

    static let longLoadThresholdNanoseconds: UInt64 = 350_000_000

    let localIdentifier: String?
    let placeholder: Placeholder

    @State private var thumbnail: UIImage?
    @State private var isLongLoading: Bool = false

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else if isLongLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.secondary)
            } else if case .image = placeholder {
                Image(systemName: "photo")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task(id: localIdentifier ?? "") { await load() }
    }

    private func load() async {
        guard let identifier = localIdentifier, !identifier.isEmpty else {
            thumbnail = nil
            isLongLoading = false
            return
        }
        if let cached = ThumbnailCache.shared.cached(localIdentifier: identifier) {
            thumbnail = cached
            isLongLoading = false
            return
        }
        let longLoadTask = Task { [thresholdNs = Self.longLoadThresholdNanoseconds] in
            try? await Task.sleep(nanoseconds: thresholdNs)
            if !Task.isCancelled {
                await MainActor.run { isLongLoading = true }
            }
        }
        let loaded = await ThumbnailCache.shared.image(for: identifier)
        longLoadTask.cancel()
        thumbnail = loaded
        isLongLoading = false
    }
}
