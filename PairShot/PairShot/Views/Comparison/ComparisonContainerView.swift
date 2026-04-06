import SwiftData
import SwiftUI

struct ComparisonContainerView: View {
    let pair: PhotoPair
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var resolvedAlignedURL: URL??
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?

    private let storage = PhotoStorageService()

    private var beforeURL: URL? {
        guard pair.beforePhoto != nil,
              let projectId = pair.project?.id
        else { return nil }
        return try? storage.photoURL(projectId: projectId, pairId: pair.id, isBefore: true)
    }

    private var afterURL: URL? {
        guard pair.afterPhoto != nil,
              let projectId = pair.project?.id
        else { return nil }
        return try? storage.photoURL(projectId: projectId, pairId: pair.id, isBefore: false)
    }

    /// resolvedAlignedURL: nil = 미검증, .some(nil) = 존재X, .some(url) = 존재O
    private var effectiveAfterURL: URL? {
        switch resolvedAlignedURL {
            case .none: afterURL
            case let .some(url): url ?? afterURL
        }
    }

    var body: some View {
        NavigationStack {
            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.medium))
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        MatchingScoreBadge(score: pair.matchingScore)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // F12 share — 미구현
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.weight(.medium))
                        }
                        .disabled(true)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .task(id: pair.id) {
            if pair.status == .complete,
               pair.alignedAfterImagePath == nil || pair.matchingScore == nil || pair
               .colorCorrectedAfterImagePath == nil
            {
                await AIAnalysisCoordinator.analyze(pairID: pair.id, in: modelContext)
            }
        }
        .task(id: pair.alignedAfterImagePath) {
            let path = pair.alignedAfterImagePath
            let projectId = pair.project?.id
            let pairId = pair.id
            let fallback = afterURL
            let candidateURL: URL? = {
                guard let path, !path.isEmpty, let projectId else { return nil }
                return try? storage.alignedPhotoURL(projectId: projectId, pairId: pairId)
            }()
            resolvedAlignedURL = await Self.resolveAlignedURL(
                candidateURL: candidateURL,
                fallback: fallback
            )
        }
        .task(
            id: "\(beforeURL?.absoluteString ?? "")|\(effectiveAfterURL?.absoluteString ?? afterURL?.absoluteString ?? "")"
        ) {
            guard let bURL = beforeURL, let aURL = effectiveAfterURL ?? afterURL else { return }
            async let bLoad = Task.detached(priority: .userInitiated) {
                ImageThumbnailLoader.load(url: bURL, maxPixelSize: 1200)
            }.value
            async let aLoad = Task.detached(priority: .userInitiated) {
                ImageThumbnailLoader.load(url: aURL, maxPixelSize: 1200)
            }.value
            let (bCG, aCG) = await (bLoad, aLoad)
            beforeImage = bCG.map { UIImage(cgImage: $0) }
            afterImage = aCG.map { UIImage(cgImage: $0) }
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        if let before = beforeURL, let after = effectiveAfterURL ?? afterURL {
            AnimationCompareView(
                beforeURL: before,
                afterURL: after,
                injectedBeforeImage: beforeImage,
                injectedAfterImage: afterImage
            )
        } else {
            Text("사진을 불러올 수 없습니다")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    nonisolated static func resolveAlignedURL(
        candidateURL: URL?,
        fallback: URL?
    ) async -> URL? {
        guard let url = candidateURL else { return fallback }
        let exists = await Task.detached {
            FileManager.default.fileExists(atPath: url.path)
        }.value
        return exists ? url : fallback
    }
}
