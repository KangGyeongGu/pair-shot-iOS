import SwiftData
import SwiftUI

enum ArchiveSortOption: String, CaseIterable, Identifiable {
    case updatedAtDesc
    case createdAtDesc

    var id: String { rawValue }

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
    @State private var sortOption: ArchiveSortOption = .updatedAtDesc

    var body: some View {
        NavigationStack {
            ProjectListContent(sortOption: sortOption)
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
                    }
                }
        }
    }
}

private struct ProjectListContent: View {
    @Query private var projects: [Project]

    init(sortOption: ArchiveSortOption) {
        let descriptor: SortDescriptor<Project>
        switch sortOption {
        case .updatedAtDesc:
            descriptor = SortDescriptor(\.updatedAt, order: .reverse)
        case .createdAtDesc:
            descriptor = SortDescriptor(\.createdAt, order: .reverse)
        }
        _projects = Query(sort: [descriptor])
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
                    ProjectRow(project: project)
                }
            }
        }
    }
}

private struct ProjectRow: View {
    let project: Project

    private var displayTitle: String {
        project.title.isEmpty ? "(이름 없음)" : project.title
    }

    private var pairCount: Int { project.pairs.count }
    private var completedCount: Int { project.pairs.filter { $0.status == .complete }.count }
    private var combinedCount: Int { project.pairs.filter { $0.combinedPath != nil }.count }

    var body: some View {
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

#Preview {
    ArchiveView()
        .modelContainer(for: [Project.self, PhotoPair.self], inMemory: true)
}
