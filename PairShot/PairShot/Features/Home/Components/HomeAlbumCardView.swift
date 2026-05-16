import SwiftUI
import UIKit

struct HomeAlbumCardView: View {
    let album: Album
    let isSelectionMode: Bool
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let label = trimmedLocation {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                        Text(label)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "camera")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                    Text("\(album.pairIds.count)")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelectionMode {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.accentColor)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Self.accessibilityLabel(
                for: album,
                isSelected: isSelected,
                isSelectionMode: isSelectionMode,
            ),
        )
    }

    private var displayName: String {
        album.name.isEmpty ? String(localized: "home_album_untitled") : album.name
    }

    private var trimmedLocation: String? {
        guard let label = album.locationLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !label.isEmpty
        else { return nil }
        return label
    }

    static func accessibilityLabel(
        for album: Album,
        isSelected: Bool,
        isSelectionMode: Bool,
    ) -> String {
        let countText = String(format: String(localized: "home_pair_count_int"), album.pairIds.count)
        let selectionText: String? =
            isSelectionMode
                ?
                (isSelected ? String(localized: "common_state_selected") :
                    String(localized: "common_state_unselected"))
                : nil
        return [album.name, countText, selectionText]
            .compactMap(\.self)
            .joined(separator: ", ")
    }
}
