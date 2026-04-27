import Foundation
import Observation
import SwiftData

struct AlbumDetailPairDeleteRequest: Identifiable {
    let id = UUID()
    let pairs: [PhotoPair]
}

struct AlbumDetailSinglePairDeleteRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

struct AlbumDetailPairPreviewRequest: Identifiable {
    let id = UUID()
    let pair: PhotoPair
}

@MainActor
@Observable
final class AlbumDetailViewModel {
    let albumId: UUID
    let storage: PhotoStorageService

    var sortOrder: HomeSortOrder = .newest

    var isSelectionMode: Bool = false
    var selectedPairIds: Set<UUID> = []

    var showRenameAlert: Bool = false
    var renameDraft: String = ""
    var showAlbumDeleteAlert: Bool = false
    var albumDeleted: Bool = false

    var pendingPairDelete: AlbumDetailPairDeleteRequest?
    var pendingSinglePairDelete: AlbumDetailSinglePairDeleteRequest?
    var pendingPreviewPair: AlbumDetailPairPreviewRequest?

    var showBeforeCamera: Bool = false
    var showAfterCamera: Bool = false
    var navigateToPairPicker: Bool = false

    private let pairRepo: PhotoPairRepository
    private let albumRepo: AlbumRepository
    private let deletePairs: DeletePairsUseCase
    private let toggleAlbumMembership: ToggleAlbumMembershipUseCase
    private let thumbnailCache: ThumbnailCache

    init(
        albumId: UUID,
        pairRepo: PhotoPairRepository,
        albumRepo: AlbumRepository,
        deletePairs: DeletePairsUseCase,
        toggleAlbumMembership: ToggleAlbumMembershipUseCase,
        storage: PhotoStorageService,
        thumbnailCache: ThumbnailCache = .shared
    ) {
        self.albumId = albumId
        self.pairRepo = pairRepo
        self.albumRepo = albumRepo
        self.deletePairs = deletePairs
        self.toggleAlbumMembership = toggleAlbumMembership
        self.storage = storage
        self.thumbnailCache = thumbnailCache
    }

    func sortedPairs(from album: Album?) -> [PhotoPair] {
        guard let album else { return [] }
        switch sortOrder {
            case .newest:
                return album.pairs.sorted { $0.createdAt > $1.createdAt }

            case .oldest:
                return album.pairs.sorted { $0.createdAt < $1.createdAt }
        }
    }

    func setSortOrder(_ order: HomeSortOrder) {
        sortOrder = order
    }

    func reload() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    func enterSelectionMode() {
        guard !isSelectionMode else { return }
        isSelectionMode = true
    }

    func cancelSelection() {
        isSelectionMode = false
        selectedPairIds.removeAll()
    }

    func togglePairSelection(_ id: UUID) {
        if selectedPairIds.contains(id) {
            selectedPairIds.remove(id)
        } else {
            selectedPairIds.insert(id)
        }
    }

    func longPressPair(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        isSelectionMode = true
        selectedPairIds = [pair.id]
    }

    func tapPair(_ pair: PhotoPair, allPairs _: [PhotoPair]) {
        if isSelectionMode {
            togglePairSelection(pair.id)
            return
        }
        if pair.afterFileName == nil {
            showAfterCamera = true
            return
        }
        pendingPreviewPair = AlbumDetailPairPreviewRequest(pair: pair)
    }

    func selectAllPairs(from all: [PhotoPair]) {
        let allIds = Set(all.map(\.id))
        selectedPairIds = selectedPairIds == allIds ? [] : allIds
    }

    func areAllPairsSelected(from all: [PhotoPair]) -> Bool {
        !all.isEmpty && selectedPairIds.count == all.count
    }

    func startCapture() {
        showBeforeCamera = true
    }

    func startPairPicker() {
        navigateToPairPicker = true
    }

    func requestPairDeletion(from all: [PhotoPair]) {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pendingPairDelete = AlbumDetailPairDeleteRequest(pairs: chosen)
    }

    func requestSinglePairDeletion(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingSinglePairDelete = AlbumDetailSinglePairDeleteRequest(pair: pair)
    }

    func hasCombined(in pairs: [PhotoPair]) -> Bool {
        pairs.contains { $0.combinedFileName != nil }
    }

    func removeFromAlbum(pairs: [PhotoPair]) async {
        for pair in pairs {
            try? await toggleAlbumMembership(
                pairId: pair.id,
                albumId: albumId,
                isIncluded: false
            )
        }
        cancelSelection()
    }

    func confirmPairDeletion(mode: DeletePairsUseCase.Mode, pairs: [PhotoPair]) async {
        let snapshots = pairs.map { pair in
            EvictionSnapshot(
                beforeFileName: pair.beforeFileName,
                afterFileName: pair.afterFileName,
                combinedFileName: pair.combinedFileName
            )
        }
        let ids = Set(pairs.map(\.id))
        try? await deletePairs(ids: ids, mode: mode)
        for snapshot in snapshots {
            evictThumbnails(for: snapshot, mode: mode)
        }
        cancelSelection()
    }

    func confirmSinglePairDeletion(_ pair: PhotoPair) async {
        let snapshot = EvictionSnapshot(
            beforeFileName: pair.beforeFileName,
            afterFileName: pair.afterFileName,
            combinedFileName: pair.combinedFileName
        )
        try? await deletePairs(ids: [pair.id], mode: .wholePair)
        evictThumbnails(for: snapshot, mode: .wholePair)
    }

    func beginRename(currentName: String) {
        renameDraft = currentName
        showRenameAlert = true
    }

    func confirmRename(album: Album) async {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        album.name = trimmed
        album.updatedAt = .now
        try? await albumRepo.update(album)
    }

    func requestAlbumDeletion() {
        showAlbumDeleteAlert = true
    }

    func confirmAlbumDeletion() async {
        try? await albumRepo.delete(id: albumId)
        albumDeleted = true
    }

    private func evictThumbnails(for snapshot: EvictionSnapshot, mode: DeletePairsUseCase.Mode) {
        switch mode {
            case .wholePair:
                thumbnailCache.evict(beforeFileName: snapshot.beforeFileName)
                if let after = snapshot.afterFileName {
                    thumbnailCache.evict(afterFileName: after)
                }
                if let combined = snapshot.combinedFileName {
                    thumbnailCache.evict(combinedFileName: combined)
                }

            case .combinedOnly:
                if let combined = snapshot.combinedFileName {
                    thumbnailCache.evict(combinedFileName: combined)
                }
        }
    }

    deinit {}
}

private struct EvictionSnapshot {
    let beforeFileName: String
    let afterFileName: String?
    let combinedFileName: String?
}
