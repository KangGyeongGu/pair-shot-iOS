import SwiftUI
import UIKit

struct BeforeCameraStrip: View {
    let pendingPairs: [PhotoPair]
    let storage: PhotoStorageService
    let onTapPair: (PhotoPair) -> Void

    var body: some View {
        Group {
            if pendingPairs.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendingPairs) { pair in
                            Button {
                                HapticService.shared.impact(.light)
                                onTapPair(pair)
                            } label: {
                                BeforeStripCard(pair: pair, storage: storage)
                                    .frame(width: 100, height: 134)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .frame(height: 168)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private var emptyState: some View {
        Text(String(localized: "아직 촬영된 Before가 없습니다"))
            .font(.caption)
            .foregroundStyle(.white.opacity(0.65))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
}

struct BeforeStripCard: View {
    let pair: PhotoPair
    let storage: PhotoStorageService

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .scaleEffect(0.85, anchor: .bottom)
        .accessibilityLabel(String(localized: "Before 사진 — After 촬영하기"))
        .task(id: pair.id) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let fileName = pair.beforeFileName
        let storageRef = storage
        let image = await Task.detached(priority: .userInitiated) {
            ThumbnailCache.shared.loadThumbnail(
                kind: .before,
                fileName: fileName,
                storage: storageRef
            )
        }.value
        thumbnail = image
    }
}
