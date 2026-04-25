import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ProjectSelection {
    var isSelectionMode: Bool = false
    var selectedIds: Set<UUID> = []

    var count: Int { selectedIds.count }

    func contains(_ id: UUID) -> Bool {
        selectedIds.contains(id)
    }

    func toggle(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    func enterSelection(with id: UUID) {
        isSelectionMode = true
        selectedIds = [id]
    }

    func exit() {
        isSelectionMode = false
        selectedIds.removeAll()
    }
}

struct MultiSelectBottomBar: View {
    let selection: ProjectSelection
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button {
                selection.exit()
            } label: {
                Label("취소", systemImage: "xmark")
                    .labelStyle(.titleOnly)
            }
            Spacer()
            Text("\(selection.count)개 선택")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("삭제", systemImage: "trash")
            }
            .disabled(selection.count == 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

enum ProjectDeletionService {
    static func deleteProjects(ids: Set<UUID>, in context: ModelContext) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { ids.contains($0.id) })
        let targets = try context.fetch(descriptor)
        for project in targets {
            context.delete(project)
        }
        try context.save()
        return targets.count
    }
}
