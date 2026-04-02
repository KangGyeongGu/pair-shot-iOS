@preconcurrency import ARKit
import SwiftData
import SwiftUI

struct PairGalleryView: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var filter: PairFilter = .all
    @State private var pairsToDelete: [PhotoPair] = []
    @State private var showDeleteConfirm = false
    @State private var cameraDestination: GalleryCameraDestination?
    @State private var arManager = ARSessionManager()

    private let storage = PhotoStorageService()
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack(alignment: .bottom) {
            if project.pairs.isEmpty {
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
                                    PairCellView(pair: pair, projectId: project.id) { tappedPair in
                                        cameraDestination = .after(pair: tappedPair)
                                    }
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

            if !project.pairs.isEmpty {
                floatingButtons
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("[AR-GALLERY] onAppear, isSessionRunning: \(arManager.isSessionRunning)")
            if !arManager.isSessionRunning {
                let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let wmURL = docsURL.appendingPathComponent("projects/\(project.id)/worldmap.arworldmap")
                if let worldMap = try? arManager.loadWorldMap(from: wmURL) {
                    arManager.startSession(withWorldMap: worldMap)
                } else {
                    arManager.startSession()
                }
            }
        }
        .onDisappear {
            print("[AR-GALLERY] onDisappear")
        }
        .confirmationDialog("페어를 삭제하시겠습니까?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                deletePairs(pairsToDelete)
                pairsToDelete = []
            }
            Button("취소", role: .cancel) {
                pairsToDelete = []
            }
        }
        .fullScreenCover(item: $cameraDestination) { destination in
            switch destination {
                case .before:
                    ARCameraView(project: project, arManager: arManager)
                case let .after(pair):
                    ARCameraView(project: project, arManager: arManager, existingPair: pair)
            }
        }
    }

    private var displayedPairs: [PhotoPair] {
        let sorted = project.pairs.sorted { lhs, rhs in
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
        project.pairs.count(where: { $0.status == .complete })
    }

    private var totalCount: Int {
        project.pairs.count
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
                cameraDestination = .before
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
        if allComplete {
            Button {} label: {
                Label("내보내기", systemImage: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(true)
        } else {
            HStack(spacing: 12) {
                Button {
                    cameraDestination = .before
                } label: {
                    Label("Before 추가", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    let firstPending = project.pairs.first { $0.status == .pendingAfter }
                    if let pair = firstPending {
                        cameraDestination = .after(pair: pair)
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
        for pair in pairs {
            let projectId = project.id
            let pairId = pair.id
            Task {
                await storage.deletePair(projectId: projectId, pairId: pairId)
            }
            modelContext.delete(pair)
        }
    }

    private func saveProjectWorldMap() async {
        guard arManager.isSessionRunning else { return }
        guard arManager.worldMappingStatus == .mapped || arManager.worldMappingStatus == .extending else { return }
        do {
            let worldMap = try await arManager.captureWorldMap()
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let wmURL = docsURL.appendingPathComponent("projects/\(project.id)/worldmap.arworldmap")
            try FileManager.default.createDirectory(
                at: wmURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try arManager.saveWorldMap(worldMap, to: wmURL)
        } catch {}
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
