import SwiftData
import SwiftUI

struct PairGalleryView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var filter: PairFilter = .all
    @State private var pairsToDelete: [PhotoPair] = []
    @State private var showDeleteConfirm = false
    @State private var presentation: GalleryPresentation?
    @State private var sensorManager = SensorManager()

    @Query private var allPairs: [PhotoPair]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(project: Project) {
        self.project = project
        let projectID = project.id
        var descriptor = FetchDescriptor<PhotoPair>(
            predicate: #Predicate { $0.project?.id == projectID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\PhotoPair.beforePhoto, \PhotoPair.afterPhoto]
        _allPairs = Query(descriptor)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if allPairs.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        completionHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        filterPicker
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)

                        let displayed = displayedPairs
                        if displayed.isEmpty {
                            filterEmptyView
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(displayed) { pair in
                                    PairCellView(
                                        pair: pair,
                                        projectId: project.id,
                                        onTapAfter: { tappedPair in
                                            presentation = .camera(.after(pair: tappedPair))
                                        },
                                        onTapCompare: { tappedPair in
                                            presentation = .comparison(tappedPair)
                                        }
                                    )
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            pairsToDelete = [pair]
                                            showDeleteConfirm = true
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }

            if !allPairs.isEmpty {
                floatingButtons
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("페어를 삭제하시겠습니까?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                deletePairs(pairsToDelete)
                pairsToDelete = []
            }
            Button("취소", role: .cancel) {
                pairsToDelete = []
            }
        }
        .fullScreenCover(item: $presentation) { mode in
            switch mode {
                case let .camera(destination):
                    switch destination {
                        case .before:
                            UnifiedCameraView(project: project, sensorManager: sensorManager)
                        case let .after(pair):
                            UnifiedCameraView(project: project, existingPair: pair, sensorManager: sensorManager)
                    }
                case let .comparison(pair):
                    ComparisonContainerView(pair: pair)
            }
        }
    }

    private var displayedPairs: [PhotoPair] {
        let sorted = allPairs.sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.status == .pendingAfter
        }
        switch filter {
            case .all:
                return sorted
            case .incomplete:
                return sorted.filter { $0.status == .pendingAfter }
            case .complete:
                return sorted.filter { $0.status == .complete }
        }
    }

    private var completedCount: Int {
        allPairs.count(where: { $0.status == .complete })
    }

    private var totalCount: Int {
        allPairs.count
    }

    private var allComplete: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    private var completionHeader: some View {
        HStack {
            if allComplete {
                Label("모두 완료", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Text("\(completedCount) / \(totalCount) 페어 완료")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProgressView(value: totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0)
                .tint(allComplete ? .green : .accentColor)
                .frame(width: 80)
        }
    }

    private var filterPicker: some View {
        Picker("필터", selection: $filter) {
            ForEach(PairFilter.allCases) { item in
                Text(item.label).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.secondary)
            Text("아직 사진이 없습니다")
                .font(.title3.weight(.semibold))
            Text("첫 Before 사진을 촬영하여\n페어를 시작하세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                presentation = .camera(.before)
            } label: {
                Label("첫 사진 촬영하기", systemImage: "camera.fill")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: filter == .incomplete ? "checkmark.circle" : "circle.dashed")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.secondary)
            Text(filter == .incomplete ? "미완료 페어가 없습니다" : "완료된 페어가 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    @ViewBuilder
    private var floatingButtons: some View {
        if !allComplete {
            HStack(spacing: 12) {
                Button {
                    presentation = .camera(.before)
                } label: {
                    Label("Before 추가", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    let firstPending = allPairs.first { $0.status == .pendingAfter }
                    if let pair = firstPending {
                        presentation = .camera(.after(pair: pair))
                    }
                } label: {
                    Label("After 촬영", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func deletePairs(_ pairs: [PhotoPair]) {
        let projectId = project.id
        let pairIds = pairs.map(\.id)
        for pair in pairs {
            modelContext.delete(pair)
        }
        Task.detached(priority: .utility) {
            let service = PhotoStorageService()
            for id in pairIds {
                service.deletePair(projectId: projectId, pairId: id)
            }
        }
    }
}

private enum GalleryCameraDestination: Identifiable {
    case before
    case after(pair: PhotoPair)

    var id: String {
        switch self {
            case .before: "before"
            case let .after(pair): "after-\(pair.id.uuidString)"
        }
    }
}

private enum GalleryPresentation: Identifiable {
    case camera(GalleryCameraDestination)
    case comparison(PhotoPair)

    var id: String {
        switch self {
            case let .camera(dest): "camera_\(dest.id)"
            case let .comparison(pair): "comparison_\(pair.id.uuidString)"
        }
    }
}

private enum PairFilter: String, CaseIterable, Identifiable {
    case all
    case incomplete
    case complete

    var id: Self {
        self
    }

    var label: String {
        switch self {
            case .all: "전체"
            case .incomplete: "미완료"
            case .complete: "완료"
        }
    }
}
