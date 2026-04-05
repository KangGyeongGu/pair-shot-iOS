import SwiftData
import SwiftUI

struct ComparisonContainerView: View {
    let pair: PhotoPair
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var mode: Mode = .sideBySide
    @State private var resolvedAlignedURL: URL??
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?

    enum Mode: String, CaseIterable, Identifiable {
        case sideBySide, slider, heatmap, animation
        var id: String {
            rawValue
        }

        var title: String {
            switch self {
                case .sideBySide: "나란히"
                case .slider: "슬라이더"
                case .heatmap: "히트맵"
                case .animation: "애니메이션"
            }
        }
    }

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
    private var effectiveBeforeURL: URL? {
        switch resolvedAlignedURL {
            case .none: beforeURL
            case let .some(url): url ?? beforeURL
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                modePicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
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
               pair.alignedBeforeImagePath == nil || pair.matchingScore == nil || pair
               .colorCorrectedBeforeImagePath == nil
            {
                await AIAnalysisCoordinator.analyze(pairID: pair.id, in: modelContext)
            }
        }
        .task(id: pair.alignedBeforeImagePath) {
            let path = pair.alignedBeforeImagePath
            let projectId = pair.project?.id
            let pairId = pair.id
            let fallback = beforeURL
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
            id: "\(effectiveBeforeURL?.absoluteString ?? beforeURL?.absoluteString ?? "")|\(afterURL?.absoluteString ?? "")"
        ) {
            guard let bURL = effectiveBeforeURL ?? beforeURL, let aURL = afterURL else { return }
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
        if let before = effectiveBeforeURL ?? beforeURL, let after = afterURL {
            switch mode {
                case .sideBySide:
                    SideBySideView(
                        beforeURL: before,
                        afterURL: after,
                        injectedBeforeImage: beforeImage,
                        injectedAfterImage: afterImage
                    )
                case .slider:
                    SliderCompareView(
                        beforeURL: before,
                        afterURL: after,
                        injectedBeforeImage: beforeImage,
                        injectedAfterImage: afterImage
                    )
                case .heatmap:
                    HeatmapView(beforeURL: before, afterURL: after)
                case .animation:
                    AnimationCompareView(
                        beforeURL: before,
                        afterURL: after,
                        injectedBeforeImage: beforeImage,
                        injectedAfterImage: afterImage
                    )
            }
        } else {
            Text("사진을 불러올 수 없습니다")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var modePicker: some View {
        Picker("비교 모드", selection: $mode) {
            ForEach(Mode.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
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
