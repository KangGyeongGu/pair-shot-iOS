import SwiftUI
import UIKit

struct AfterCameraStrip: View {
    let pairs: [PhotoPair]
    @Binding var selectedPairId: UUID?
    let storage: PhotoStorageService
    let progress: AfterCameraStripProgress?

    var body: some View {
        VStack(spacing: 0) {
            scrollArea
            if let progress {
                AfterCameraStripProgressBar(progress: progress)
                    .frame(height: 28)
            }
        }
        .frame(height: 168)
        .frame(maxWidth: .infinity)
        .background(Color.appLetterbox)
    }

    private var scrollArea: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(pairs) { pair in
                        AfterStripCard(
                            pair: pair,
                            isActive: pair.id == selectedPairId,
                            storage: storage
                        )
                        .id(pair.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, max(20, (proxy.size.width - AfterStripMetrics.cardWidth) / 2))
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedPairId)
            .onChange(of: selectedPairId) { _, _ in
                HapticService.shared.impact(.light)
            }
        }
    }
}

struct AfterCameraStripProgress: Equatable {
    let completed: Int
    let total: Int
}

struct AfterCameraStripProgressBar: View {
    let progress: AfterCameraStripProgress

    var body: some View {
        Text(String(
            format: String(localized: "after_strip_progress"),
            progress.completed,
            progress.total
        ))
        .font(.caption.monospacedDigit())
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

enum AfterStripMetrics {
    static let cardWidth: CGFloat = 100
    static let cardHeight: CGFloat = 134
    static let cornerRadius: CGFloat = 10
}

struct AfterStripCard: View {
    let pair: PhotoPair
    let isActive: Bool
    let storage: PhotoStorageService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AfterStripMetrics.cornerRadius)
                .fill(Color.white.opacity(0.06))

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(width: AfterStripMetrics.cardWidth, height: AfterStripMetrics.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: AfterStripMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AfterStripMetrics.cornerRadius)
                .stroke(
                    isActive ? Color.yellow : Color.white.opacity(0.3),
                    lineWidth: isActive ? 3 : 1
                )
        )
        .scaleEffect(isActive ? 1.0 : 0.85, anchor: .bottom)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isActive)
        .accessibilityLabel(String(localized: "after_strip_target_pair_desc"))
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
