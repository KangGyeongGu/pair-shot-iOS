import SwiftData
import SwiftUI

struct ComparisonContainerView: View {
    let pair: PhotoPair
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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

    private var alignedAfterURL: URL? {
        guard let path = pair.alignedAfterImagePath, !path.isEmpty,
              let projectId = pair.project?.id
        else { return nil }
        guard let url = try? storage.alignedPhotoURL(projectId: projectId, pairId: pair.id),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { dismiss() } label: {
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
    }

    @ViewBuilder
    private var modeContent: some View {
        if let before = beforeURL, let after = afterURL {
            AnimationCompareView(
                beforeURL: before,
                afterURL: after,
                alignedAfterURL: alignedAfterURL
            )
        } else {
            Text("사진을 불러올 수 없습니다")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
