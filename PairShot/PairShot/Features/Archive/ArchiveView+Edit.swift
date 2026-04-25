import SwiftData
import SwiftUI

struct EditProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let project: Project

    @State private var title: String

    init(project: Project) {
        self.project = project
        _title = State(initialValue: project.title)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("프로젝트 정보") {
                    TextField("제목", text: $title)
                }
            }
            .navigationTitle("프로젝트 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        ProjectRenameService.rename(project, to: trimmedTitle, in: modelContext)
        dismiss()
    }
}

enum ProjectRenameService {
    static func rename(_ project: Project, to newTitle: String, in context: ModelContext) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != project.title else { return }
        project.title = trimmed
        project.updatedAt = .now
        try? context.save()
    }
}
