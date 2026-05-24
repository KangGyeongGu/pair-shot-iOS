@MainActor
struct PairDeletionCoordinator {
    let deletePairs: DeletePairsUseCase
    let deleteCombinedExports: DeleteCombinedExportsUseCase
    let deletePairsKeepingCombined: DeletePairsKeepingCombinedUseCase
    let thumbnailCache: PhotoLibraryThumbnailCache

    func deletePairsWithThumbnailEviction(_ pairs: [PhotoPair]) async {
        let snapshots = thumbnailSnapshots(for: pairs)
        let ids = Set(pairs.map(\.id))
        try? await deletePairs(ids: ids)
        evictThumbnails(for: snapshots)
    }

    func deleteOriginalsKeepingCombined(_ pairs: [PhotoPair]) async {
        let snapshots = thumbnailSnapshots(for: pairs)
        let ids = Set(pairs.map(\.id))
        try? await deletePairsKeepingCombined(ids: ids)
        evictThumbnails(for: snapshots)
    }

    func deleteCombinedOnly(_ pairs: [PhotoPair]) async {
        let ids = Set(pairs.map(\.id))
        try? await deleteCombinedExports(ids: ids)
    }

    func deleteSinglePairWithThumbnailEviction(_ pair: PhotoPair) async {
        let beforeId = pair.beforePhotoLocalIdentifier
        let afterId = pair.afterPhotoLocalIdentifier
        try? await deletePairs(ids: [pair.id])
        evictThumbnails(beforeIdentifier: beforeId, afterIdentifier: afterId)
    }

    func deleteSingleOriginalKeepingCombined(_ pair: PhotoPair) async {
        let beforeId = pair.beforePhotoLocalIdentifier
        let afterId = pair.afterPhotoLocalIdentifier
        try? await deletePairsKeepingCombined(ids: [pair.id])
        evictThumbnails(beforeIdentifier: beforeId, afterIdentifier: afterId)
    }

    func deleteSingleCombinedOnly(_ pair: PhotoPair) async {
        try? await deleteCombinedExports(ids: [pair.id])
    }

    func evictThumbnails(beforeIdentifier: String?, afterIdentifier: String?) {
        if let beforeIdentifier {
            thumbnailCache.evict(localIdentifier: beforeIdentifier)
        }
        if let afterIdentifier {
            thumbnailCache.evict(localIdentifier: afterIdentifier)
        }
    }

    private func thumbnailSnapshots(for pairs: [PhotoPair]) -> [(before: String?, after: String?)] {
        pairs.map { ($0.beforePhotoLocalIdentifier, $0.afterPhotoLocalIdentifier) }
    }

    private func evictThumbnails(for snapshots: [(before: String?, after: String?)]) {
        for snapshot in snapshots {
            evictThumbnails(beforeIdentifier: snapshot.before, afterIdentifier: snapshot.after)
        }
    }
}
