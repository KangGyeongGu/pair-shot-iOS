import Foundation
import SwiftData
import SwiftUI

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
            Text(String(format: String(localized: "%d개 선택"), selection.count))
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onComposite()
            } label: {
                Label(String(localized: "합성"), systemImage: "square.on.square")
            }
            .disabled(true)
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

enum PairDeletionService {
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
            storage.deletePhotosForPair(
                beforeFileName: pair.beforeFileName,
                afterFileName: pair.afterFileName,
                combinedFileName: pair.combinedFileName
            )
            ThumbnailCache.shared.evict(beforeFileName: pair.beforeFileName)
            if let after = pair.afterFileName {
                ThumbnailCache.shared.evict(afterFileName: after)
            }
            if let combined = pair.combinedFileName {
                ThumbnailCache.shared.evict(combinedFileName: combined)
            }
            context.delete(pair)
        }
        try context.save()
        return targets.count
    }
}

enum AlbumDeletionService {
    /// Deletes albums by id. Pairs survive — their `albums` relationship is
    /// nullified by SwiftData; the spec calls for "앨범을 삭제하시겠습니까?
    /// 페어는 유지됩니다."
    @discardableResult
    static func deleteAlbums(
        ids: Set<UUID>,
        in context: ModelContext
    ) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<Album>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let targets = try context.fetch(descriptor)
        for album in targets {
            context.delete(album)
        }
        try context.save()
        return targets.count
    }
}
