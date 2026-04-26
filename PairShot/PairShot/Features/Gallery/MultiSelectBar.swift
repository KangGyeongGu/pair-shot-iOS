import Foundation
import SwiftData
import SwiftUI

/// P4.3 — multi-select state and bottom action bar for `PairGalleryView`.
/// Mirrors the `ProjectSelection` / `MultiSelectBottomBar` pattern from
/// Phase 1.4 but operates on `PhotoPair.id` instead of `Project.id`.
///
/// Kept as a separate file (and separate `@Observable` class) so that
/// gallery and archive can evolve their selection UX independently — e.g.
/// gallery may grow a "select all visible after filter" affordance later.
@MainActor
@Observable
final class PairSelection {
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

/// Bottom action bar shown via `safeAreaInset(.bottom)` while
/// `PairSelection.isSelectionMode == true`. Three actions:
///
/// - **합성** (composite): placeholder slot — wired by `ComparisonView` for
///   single-pair edits, multi-pair composite is a future enhancement.
/// - **공유** (share): wired in P7 via `ExportPicker` — bundles the selected
///   pairs into a ZIP / saves to Photos library / hands UIImage list to the
///   activity sheet.
/// - **삭제** (delete): wired in P4.3 via `PairDeletionService`.
struct PairMultiSelectBar: View {
    let selection: PairSelection
    let onComposite: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button {
                selection.exit()
            } label: {
                Label(String(localized: "취소"), systemImage: "xmark")
                    .labelStyle(.titleOnly)
            }
            Spacer()
            Text("\(selection.count)\(String(localized: "개 선택"))")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onComposite()
            } label: {
                Label(String(localized: "합성"), systemImage: "square.on.square")
            }
            .disabled(true) // Multi-pair composite is a future enhancement.
            Button {
                onShare()
            } label: {
                Label(String(localized: "공유"), systemImage: "square.and.arrow.up")
            }
            .disabled(selection.selectedIds.isEmpty)
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: "삭제"), systemImage: "trash")
            }
            .disabled(selection.selectedIds.isEmpty)
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

/// Deletes a set of `PhotoPair`s by id, removing both the SwiftData rows
/// and the underlying JPEG files. Cascade deletes are handled by SwiftData
/// at the project level (Phase 1.4); here we touch leaves directly.
///
/// File deletion is best-effort: a missing JPEG does not block the SwiftData
/// row from being removed (otherwise an out-of-band file delete would
/// permanently strand orphan rows).
enum PairDeletionService {
    /// - Parameters:
    ///   - ids: PhotoPair ids to delete.
    ///   - context: backing `ModelContext`.
    ///   - storage: file-deletion seam — defaults to a fresh
    ///     `PhotoStorageService()`. Tests can inject a temp-dir instance.
    /// - Returns: number of `PhotoPair` rows actually deleted.
    @discardableResult
    static func deletePairs(
        ids: Set<UUID>,
        in context: ModelContext,
        storage: PhotoStorageService = PhotoStorageService()
    ) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<PhotoPair>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let targets = try context.fetch(descriptor)
        for pair in targets {
            // Best-effort file unlink. Failures are swallowed so the SwiftData
            // delete can still proceed; orphaning a row to chase a missing
            // file would be worse UX than orphaning a file.
            try? storage.deletePhoto(at: pair.beforePath)
            if let after = pair.afterPath {
                try? storage.deletePhoto(at: after)
            }
            if let combined = pair.combinedPath {
                try? storage.deletePhoto(at: combined)
            }
            ThumbnailCache.shared.evict(relativePath: pair.beforePath)
            if let after = pair.afterPath {
                ThumbnailCache.shared.evict(relativePath: after)
            }
            if let combined = pair.combinedPath {
                ThumbnailCache.shared.evict(relativePath: combined)
            }
            context.delete(pair)
        }
        try context.save()
        return targets.count
    }
}
