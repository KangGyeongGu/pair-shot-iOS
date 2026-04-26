import SwiftData
import SwiftUI

enum ArchiveSortOption: String, CaseIterable, Identifiable {
    case updatedAtDesc
    case createdAtDesc

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
            case .updatedAtDesc: "최근 수정"
            case .createdAtDesc: "생성일"
        }
    }

    var systemImage: String {
        switch self {
            case .updatedAtDesc: "clock.arrow.circlepath"
            case .createdAtDesc: "calendar"
        }
    }
}

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sortOption: ArchiveSortOption = .updatedAtDesc
    @State private var showingNewProject: Bool = false
    @State private var showingSettings: Bool = false
    @State private var renameTarget: Project?
    @State private var selection = ProjectSelection()

    private let locationServiceFactory: @Sendable @MainActor () -> any LocationProviding

    init(locationServiceFactory: @escaping @Sendable @MainActor ()
        -> any LocationProviding = { CoreLocationService() })
    {
        self.locationServiceFactory = locationServiceFactory
    }

    var body: some View {
        NavigationStack {
            ProjectListContent(
                sortOption: sortOption,
                selection: selection,
                onLongPress: { project in
                    if !selection.isSelectionMode {
                        selection.enterSelection(with: project.id)
                    }
                },
                onTap: { project in
                    if selection.isSelectionMode {
                        selection.toggle(project.id)
                    }
                },
                onRename: { project in
                    renameTarget = project
                }
            )
            .navigationTitle("프로젝트")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("정렬", selection: $sortOption) {
                            ForEach(ArchiveSortOption.allCases) { option in
                                Label(option.label, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }
                    } label: {
                        Label("정렬", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(selection.isSelectionMode)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("설정", systemImage: "gearshape")
                    }
                    .disabled(selection.isSelectionMode)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewProject = true
                    } label: {
                        Label("새 프로젝트", systemImage: "plus")
                    }
                    .disabled(selection.isSelectionMode)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Stack the banner above the multi-select bar so neither
                // covers the other. Per Android v1.1.3 mapping the banner
                // is always on regardless of selection mode; AdFree
                // collapses it to nothing via `BannerAdSlot`.
                VStack(spacing: 0) {
                    BannerAdSlot()
                    if selection.isSelectionMode {
                        MultiSelectBottomBar(selection: selection) {
                            deleteSelected()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewProject) {
                NewProjectSheet(locationService: locationServiceFactory())
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $renameTarget) { project in
                EditProjectSheet(project: project)
            }
        }
    }

    private func deleteSelected() {
        let ids = selection.selectedIds
        guard !ids.isEmpty else { return }
        _ = try? ProjectDeletionService.deleteProjects(ids: ids, in: modelContext)
        selection.exit()
    }
}

private struct ProjectListContent: View {
    @Query private var projects: [Project]

    let selection: ProjectSelection
    let onLongPress: (Project) -> Void
    let onTap: (Project) -> Void
    let onRename: (Project) -> Void

    init(
        sortOption: ArchiveSortOption,
        selection: ProjectSelection,
        onLongPress: @escaping (Project) -> Void,
        onTap: @escaping (Project) -> Void,
        onRename: @escaping (Project) -> Void
    ) {
        let descriptor: SortDescriptor<Project> = switch sortOption {
            case .updatedAtDesc:
                SortDescriptor(\.updatedAt, order: .reverse)
            case .createdAtDesc:
                SortDescriptor(\.createdAt, order: .reverse)
        }
        _projects = Query(sort: [descriptor])
        self.selection = selection
        self.onLongPress = onLongPress
        self.onTap = onTap
        self.onRename = onRename
    }

    var body: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView(
                    "프로젝트 없음",
                    systemImage: "folder.badge.plus",
                    description: Text("우상단 + 버튼으로 새 프로젝트를 만드세요")
                )
            } else {
                List(projects) { project in
                    ProjectRow(
                        project: project,
                        isSelectionMode: selection.isSelectionMode,
                        isSelected: selection.contains(project.id)
                    )
                    .contentShape(.rect)
                    .onTapGesture { onTap(project) }
                    .onLongPressGesture(minimumDuration: 0.4) { onLongPress(project) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !selection.isSelectionMode {
                            Button {
                                onRename(project)
                            } label: {
                                Label("이름 변경", systemImage: "pencil")
                            }
                            .tint(.indigo)
                        }
                    }
                }
            }
        }
    }
}

private struct ProjectRow: View {
    let project: Project
    let isSelectionMode: Bool
    let isSelected: Bool

    private var displayTitle: String {
        project.title.isEmpty ? "(이름 없음)" : project.title
    }

    private var pairCount: Int {
        project.pairs.count
    }

    private var completedCount: Int {
        project.pairs.count(where: { $0.status == .complete })
    }

    private var combinedCount: Int {
        project.pairs.count(where: { $0.combinedPath != nil })
    }

    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(displayTitle).font(.headline)
                    Spacer()
                    Text(project.updatedAt, format: .dateTime.month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    CountBadge(label: "페어", count: pairCount, tint: .blue)
                    CountBadge(label: "완료", count: completedCount, tint: .green)
                    CountBadge(label: "합성", count: combinedCount, tint: .purple)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CountBadge: View {
    let label: String
    let count: Int
    let tint: Color

    var body: some View {
        Text("\(label) \(count)")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: .capsule)
            .foregroundStyle(tint)
    }
}

private struct ArchiveViewPreviewWrapper: View {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Project.self,
        PhotoPair.self,
        Coupon.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        ArchiveView()
            .modelContainer(container)
            .environment(AdFreeStore(context: container.mainContext))
            .environment(AppSettings(defaults: UserDefaults(suiteName: "preview-archive") ?? .standard))
    }
}

#Preview {
    ArchiveViewPreviewWrapper()
}
