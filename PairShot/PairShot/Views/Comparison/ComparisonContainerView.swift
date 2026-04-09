import SwiftData
import SwiftUI

struct ComparisonContainerView: View {
    let pair: PhotoPair
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var alignedAfterURLResolved: URL?

    private let storage = PhotoStorageService()

    private var alignmentTierLabel: String? {
        switch pair.alignmentTierRaw {
            case "tier1": "기본 보정"
            case "tier2": "포즈 보정"
            case "tier3": "정밀 보정"
            case "failed": "보정 실패"
            default: nil
        }
    }

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

    private func resolvedAlignedAfterURL() async -> URL? {
        guard let path = pair.alignedAfterImagePath, !path.isEmpty,
              let projectId = pair.project?.id
        else { return nil }
        guard let url = try? storage.alignedPhotoURL(projectId: projectId, pairId: pair.id)
        else { return nil }
        let exists = await Task.detached { FileManager.default.fileExists(atPath: url.path) }.value
        return exists ? url : nil
    }

    var body: some View {
        NavigationStack {
            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.medium))
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            MatchingScoreBadge(score: pair.matchingScore)
                            if let tierLabel = alignmentTierLabel {
                                Text(tierLabel)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
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
            alignedAfterURLResolved = await resolvedAlignedAfterURL()
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        if let before = beforeURL, let after = afterURL {
            AnimationCompareView(
                beforeURL: before,
                afterURL: after,
                alignedAfterURL: alignedAfterURLResolved
            )
        } else {
            Text("사진을 불러올 수 없습니다")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
