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
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "camera")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(String(format: String(localized: "%lld"), album.pairs.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(
            for: album,
            isSelected: isSelected,
            isSelectionMode: isSelectionMode
        ))
    }

    static func accessibilityLabel(
        for album: Album,
        isSelected: Bool,
        isSelectionMode: Bool
    ) -> String {
        let countText = String(format: String(localized: "%d개 페어"), album.pairs.count)
        let selectionText: String? = isSelectionMode
            ? (isSelected ? String(localized: "선택됨") : String(localized: "선택 안 됨"))
            : nil
        return [album.name, countText, selectionText]
            .compactMap(\.self)
            .joined(separator: ", ")
    }

    private var displayName: String {
        album.name.isEmpty ? String(localized: "(이름 없음)") : album.name
    }

    private var trimmedLocation: String? {
        guard let label = album.locationLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !label.isEmpty
        else { return nil }
        return label
    }
}

struct AlbumCoverSource: Identifiable, Hashable {
    let id = UUID()
    let kind: PhotoStorageService.PhotoKind
    let fileName: String
}
