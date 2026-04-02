import SwiftUI

struct PairCellView: View {
    let pair: PhotoPair
    let projectId: UUID
    var onTapAfter: ((PhotoPair) -> Void)?

    @State private var beforeThumb: UIImage?
    @State private var afterThumb: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                thumbnailSlot(image: beforeThumb, isBefore: true)
                thumbnailSlot(image: afterThumb, isBefore: false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        pair.status == .pendingAfter ? Color.red.opacity(0.8) : Color.clear,
                        lineWidth: 2
                    )
            )

            if pair.status == .pendingAfter {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                    Text("After 미촬영")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if pair.status == .pendingAfter {
                onTapAfter?(pair)
            }
        }
        .task(id: pair.beforePhoto?.thumbnailPath) {
            beforeThumb = await loadThumbnailAsync(isBefore: true)
        }
        .task(id: pair.afterPhoto?.thumbnailPath) {
            afterThumb = await loadThumbnailAsync(isBefore: false)
        }
    }

    private func thumbnailSlot(image: UIImage?, isBefore: Bool) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.systemGray5)
                    if !isBefore {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(.secondary)
                            Text("After")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }

    private func loadThumbnailAsync(isBefore: Bool) async -> UIImage? {
        let storage = PhotoStorageService()
        guard let url = try? storage.thumbnailURL(
            projectId: projectId,
            pairId: pair.id,
            isBefore: isBefore
        ) else { return nil }
        return ThumbnailCache.shared.image(for: url.path)
    }
}
