import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "프로젝트 없음",
                        systemImage: "folder.badge.plus",
                        description: Text("Phase 1.2에서 프로젝트 생성 UI 추가 예정")
                    )
                } else {
                    List(projects) { project in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.title).font(.headline)
                            Text(project.createdAt, format: .dateTime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("PairShot")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, PhotoPair.self], inMemory: true)
}
