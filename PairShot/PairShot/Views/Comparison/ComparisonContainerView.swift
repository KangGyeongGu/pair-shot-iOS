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
                    scoreBadge
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

    private var modeContent: some View {
        GeometryReader { geometry in
            switch mode {
                case .sideBySide:
                    placeholderView(label: "나란히 비교 (W10 pending)", geometry: geometry)
                case .slider:
                    placeholderView(label: "슬라이더 비교 (W11 pending)", geometry: geometry)
                case .heatmap:
                    placeholderView(label: "히트맵 (W12 pending)", geometry: geometry)
                case .animation:
                    placeholderView(label: "애니메이션 비교 (W13 pending)", geometry: geometry)
            }
        }
    }

    private func placeholderView(label: String, geometry: GeometryProxy) -> some View {
        Text(label)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(width: geometry.size.width, height: geometry.size.height)
    }

    private var modePicker: some View {
        Picker("비교 모드", selection: $mode) {
            ForEach(Mode.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var scoreBadge: some View {
        if let score = pair.matchingScore {
            let percent = MatchingScoreService.percentMatch(for: score)
            let grade = MatchingScoreService.grade(for: score)
            Text("\(percent)% 일치")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(gradeColor(grade))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(gradeColor(grade).opacity(0.15), in: Capsule())
        } else {
            Text("분석 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func gradeColor(_ grade: MatchingScoreService.MatchingGrade) -> Color {
        switch grade {
            case .excellent: .green
            case .good: .yellow
            case .retake: .red
        }
    }
}
