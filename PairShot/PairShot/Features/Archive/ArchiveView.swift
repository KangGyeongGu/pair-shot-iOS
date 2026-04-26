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
            case .updatedAtDesc: String(localized: "최근 수정")
            case .createdAtDesc: String(localized: "생성일")
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
            // Audit-A — push `PairGalleryView` when a row's
            // `NavigationLink(value: project)` fires from `ProjectListContent`.
            // Selection mode short-circuits the link inside the row so
            // multi-select toggles don't accidentally navigate.
            .navigationDestination(for: Project.self) { project in
                PairGalleryView(project: project)
            }
            .navigationTitle(String(localized: "프로젝트"))
            .toolbar { toolbarContent }
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker(String(localized: "정렬"), selection: $sortOption) {
                    ForEach(ArchiveSortOption.allCases) { option in
                        Label(option.label, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
            } label: {
                Label(String(localized: "정렬"), systemImage: "arrow.up.arrow.down")
            }
            .disabled(selection.isSelectionMode)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Label(String(localized: "설정"), systemImage: "gearshape")
            }
            .disabled(selection.isSelectionMode)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingNewProject = true
            } label: {
                Label(String(localized: "새 프로젝트"), systemImage: "plus")
            }
            .disabled(selection.isSelectionMode)
        }
    }

    private func deleteSelected() {
        let ids = selection.selectedIds
        guard !ids.isEmpty else { return }
        // Audit-A — pass the production `PhotoStorageService` so the
        // cascade also unlinks the JPEGs and evicts the thumbnail
        // cache, not just the SwiftData rows.
        _ = try? ProjectDeletionService.deleteProjects(
            ids: ids,
            in: modelContext,
            storage: PhotoStorageService()
        )
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
                    String(localized: "프로젝트 없음"),
                    systemImage: "folder.badge.plus",
                    description: Text(String(localized: "우상단 + 버튼으로 새 프로젝트를 만드세요"))
                )
            } else {
                List(projects) { project in
                    projectRow(for: project)
                }
            }
        }
    }

    /// Row builder. Audit-A — uses `NavigationLink(value:)` to push
    /// `PairGalleryView` when **not** in selection mode; in selection
    /// mode we fall back to a plain row + `onTapGesture` so tap toggles
    /// the checkmark instead of navigating.
    @ViewBuilder
    private func projectRow(for project: Project) -> some View {
        if selection.isSelectionMode {
            ProjectRow(
                project: project,
                isSelectionMode: true,
                isSelected: selection.contains(project.id)
            )
            .contentShape(.rect)
            .onTapGesture { onTap(project) }
            .onLongPressGesture(minimumDuration: 0.4) { onLongPress(project) }
        } else {
            NavigationLink(value: project) {
                ProjectRow(
                    project: project,
                    isSelectionMode: false,
                    isSelected: false
                )
            }
            .contentShape(.rect)
            .onLongPressGesture(minimumDuration: 0.4) { onLongPress(project) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    onRename(project)
                } label: {
                    Label(String(localized: "이름 변경"), systemImage: "pencil")
                }
                .tint(.indigo)
            }
        }
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
