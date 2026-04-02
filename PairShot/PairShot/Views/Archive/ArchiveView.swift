import SwiftData
import SwiftUI

struct ArchiveView: View {
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @Environment(\.modelContext) private var modelContext

    @State private var showNewProjectSheet = false
    @State private var pendingProject: Project?
    @State private var projectToDelete: Project?
    @State private var showDeleteAlert = false
    @State private var projectToRename: Project?
    @State private var renameText: String = ""
    @State private var showRenameAlert = false
    @State private var navigationPath = NavigationPath()
    @State private var isSelectionMode = false
    @State private var selectedProjects: Set<UUID> = []

    private let storage = PhotoStorageService()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if projects.isEmpty {
                    emptyStateView
                } else {
                    projectList
                }
            }
            .navigationTitle("현장 목록")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if isSelectionMode {
                        Button("완료") {
                            isSelectionMode = false
                            selectedProjects.removeAll()
                        }
                    } else {
                        Menu {
                            Button {
                                showNewProjectSheet = true
                            } label: {
                                Label("새 현장 추가", systemImage: "plus")
                            }
                            Button {
                                isSelectionMode = true
                            } label: {
                                Label("선택", systemImage: "checkmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                if isSelectionMode, !selectedProjects.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                            projectToDelete = nil
                        } label: {
                            Label("선택 항목 삭제 (\(selectedProjects.count))", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationDestination(for: Project.self) { project in
                PairGalleryView(project: project)
            }
        }
        .sheet(
            isPresented: $showNewProjectSheet,
            onDismiss: {
                if let project = pendingProject {
                    navigationPath.append(project)
                    pendingProject = nil
                }
            },
            content: {
                NewProjectSheet { project in
                    pendingProject = project
                }
            }
        )
        .alert("프로젝트 삭제", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                if let single = projectToDelete {
                    deleteProject(single)
                    projectToDelete = nil
                } else if !selectedProjects.isEmpty {
                    deleteSelectedProjects()
                }
            }
            Button("취소", role: .cancel) {
                projectToDelete = nil
            }
        } message: {
            if let single = projectToDelete {
                Text("'\(single.title)' 현장의 모든 사진이 삭제됩니다.")
            } else {
                Text("\(selectedProjects.count)개 현장의 모든 사진이 삭제됩니다.")
            }
        }
        .alert("이름 변경", isPresented: $showRenameAlert) {
            TextField("현장 이름", text: $renameText)
            Button("확인") {
                if let project = projectToRename {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        project.title = trimmed
                    }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("새 이름을 입력하세요.")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("현장이 없습니다")
                    .font(.title3.weight(.semibold))
                Text("새 현장 촬영을 시작하세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            newShootButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var projectList: some View {
        List(selection: isSelectionMode ? $selectedProjects : nil) {
            ForEach(projects) { project in
                if isSelectionMode {
                    ProjectRowView(project: project)
                        .tag(project.id)
                } else {
                    NavigationLink(value: project) {
                        ProjectRowView(project: project)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            projectToDelete = project
                            showDeleteAlert = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            projectToRename = project
                            renameText = project.title
                            showRenameAlert = true
                        } label: {
                            Label("이름 변경", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            projectToDelete = project
                            showDeleteAlert = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }

            if !isSelectionMode {
                Section {
                    newShootButton
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(isSelectionMode ? .active : .inactive))
    }

    private var newShootButton: some View {
        Button {
            showNewProjectSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text("새 현장 촬영")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func deleteProject(_ project: Project) {
        let projectId = project.id
        Task { await storage.deleteProject(projectId: projectId) }
        modelContext.delete(project)
    }

    private func deleteSelectedProjects() {
        let toDelete = projects.filter { selectedProjects.contains($0.id) }
        for project in toDelete {
            let projectId = project.id
            Task { await storage.deleteProject(projectId: projectId) }
            modelContext.delete(project)
        }
        selectedProjects.removeAll()
        isSelectionMode = false
    }
}

private struct ProjectRowView: View {
    let project: Project

    private var completedCount: Int {
        project.pairs.count(where: { $0.status == .complete })
    }

    private var totalCount: Int {
        project.pairs.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.title)
                .font(.body.weight(.medium))
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(completionLabel)
                    .font(.subheadline)
                    .foregroundStyle(completionColor)

                Text("·")
                    .foregroundStyle(.secondary)

                Text(project.createdAt, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var completionLabel: String {
        if totalCount == 0 {
            "사진 없음"
        } else {
            "\(completedCount)/\(totalCount) 완료"
        }
    }

    private var completionColor: Color {
        if totalCount == 0 {
            .secondary
        } else if completedCount == totalCount {
            .green
        } else {
            .accentColor
        }
    }
}

enum CameraDestination: Identifiable {
    case beforeCamera(project: Project)
    case afterCamera(project: Project, pair: PhotoPair)

    var id: String {
        switch self {
            case let .beforeCamera(project):
                "before-\(project.id.uuidString)"
            case let .afterCamera(project, pair):
                "after-\(project.id.uuidString)-\(pair.id.uuidString)"
        }
    }
}
