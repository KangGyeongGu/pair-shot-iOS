import SwiftUI

struct ComparisonContainerView: View {
    let pair: PhotoPair
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .sideBySide

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

    private var alignedBeforeURL: URL? {
        guard let projectId = pair.project?.id,
              pair.alignedBeforeImagePath != nil
        else { return beforeURL }
        return try? storage.alignedPhotoURL(projectId: projectId, pairId: pair.id)
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
                        print("TODO: F12 share")
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.medium))
                    }
                    .disabled(true)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        if let before = alignedBeforeURL, let after = afterURL {
            switch mode {
                case .sideBySide:
                    SideBySideView(beforeURL: before, afterURL: after)
                case .slider:
                    SliderCompareView(beforeURL: before, afterURL: after)
                case .heatmap:
                    HeatmapView(beforeURL: before, afterURL: after)
                case .animation:
                    AnimationCompareView(beforeURL: before, afterURL: after)
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
}
