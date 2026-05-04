import SwiftUI

struct AlbumDetailEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(.secondary)

            Text(String(localized: "album_empty_pairs"))
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}
