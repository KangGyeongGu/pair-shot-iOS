import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ProjectSelection {
    var isSelectionMode: Bool = false
    var selectedIds: Set<UUID> = []

    var count: Int {
        selectedIds.count
    }

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
    /// Removes each `Project` whose `id` is in `ids`, *plus* the JPEG
    /// files referenced by each pair (`beforePath` / `afterPath` /
    /// `combinedPath`) and any decoded `ThumbnailCache` entries.
    ///
    /// Audit-A — until this fix, SwiftData's `@Relationship .cascade`
    /// only removed the `PhotoPair` rows; the underlying files stayed
    /// orphaned in `Application Support/photos/`, eventually filling
    /// the user's storage with photos they thought they had deleted.
    /// File deletion is best-effort: a missing JPEG does not abort the
    /// SwiftData delete (an out-of-band file delete must not strand
    /// rows forever).
    ///
    /// - Parameters:
    ///   - ids: Project ids to delete.
    ///   - context: backing `ModelContext`.
    ///   - storage: file-deletion seam — defaults to a fresh
    ///     `PhotoStorageService()`. Tests inject a temp-dir instance.
    /// - Returns: number of `Project` rows actually deleted.
    @discardableResult
    static func deleteProjects(
        ids: Set<UUID>,
        in context: ModelContext,
        storage: PhotoStorageService = PhotoStorageService()
    ) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { ids.contains($0.id) })
        let targets = try context.fetch(descriptor)
        for project in targets {
            // Snapshot the pair list before SwiftData starts tearing it
            // down via the cascade rule — accessing `project.pairs`
            // post-delete is undefined.
            for pair in project.pairs {
                deleteFiles(for: pair, storage: storage)
            }
            context.delete(project)
        }
        try context.save()
        return targets.count
    }

    /// Best-effort unlink + thumbnail evict for one pair's three
    /// possible JPEG paths. Failures are swallowed so a stuck file
    /// (eg. another process holding the inode) cannot block the
    /// SwiftData row deletion.
    private static func deleteFiles(for pair: PhotoPair, storage: PhotoStorageService) {
        try? storage.deletePhoto(at: pair.beforePath)
        ThumbnailCache.shared.evict(relativePath: pair.beforePath)
        if let after = pair.afterPath {
            try? storage.deletePhoto(at: after)
            ThumbnailCache.shared.evict(relativePath: after)
        }
        if let combined = pair.combinedPath {
            try? storage.deletePhoto(at: combined)
            ThumbnailCache.shared.evict(relativePath: combined)
        }
    }
}
