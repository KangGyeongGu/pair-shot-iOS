import Foundation

extension AlbumDetailViewModel {
    var deletionCoordinator: PairDeletionCoordinator {
        PairDeletionCoordinator(
            deletePairs: deletePairs,
            deleteCombinedExports: deleteCombinedExports,
            deletePairsKeepingCombined: deletePairsKeepingCombined,
            thumbnailCache: thumbnailCache
        )
    }

    func confirmPairDeletion(pairs: [PhotoPair]) async {
        await deletionCoordinator.deletePairsWithThumbnailEviction(pairs)
        cancelSelection()
    }

    func confirmOriginalOnlyDeletion(pairs: [PhotoPair]) async {
        await deletionCoordinator.deleteOriginalsKeepingCombined(pairs)
        cancelSelection()
    }

    func confirmSinglePairDeletion(_ pair: PhotoPair) async {
        await deletionCoordinator.deleteSinglePairWithThumbnailEviction(pair)
    }

    func confirmSingleOriginalOnlyDeletion(_ pair: PhotoPair) async {
        await deletionCoordinator.deleteSingleOriginalKeepingCombined(pair)
    }

    func confirmCombinedDeletion(pairs: [PhotoPair]) async {
        await deletionCoordinator.deleteCombinedOnly(pairs)
        cancelSelection()
    }

    func confirmSingleCombinedDeletion(_ pair: PhotoPair) async {
        await deletionCoordinator.deleteSingleCombinedOnly(pair)
    }

    func confirmAlbumDeletion() async {
        try? await albumRepo.delete(id: albumId)
        albumDeleted = true
    }

    func confirmAlbumDeletionAllPairs(album: Album) async {
        let pairIds = Set(album.pairIds)
        if !pairIds.isEmpty {
            try? await deletePairs(ids: pairIds)
        }
        try? await albumRepo.delete(id: albumId)
        albumDeleted = true
    }

    func confirmAlbumDeletionOriginalOnly(album: Album) async {
        let pairIds = Set(album.pairIds)
        if !pairIds.isEmpty {
            try? await deletePairsKeepingCombined(ids: pairIds)
        }
        try? await albumRepo.delete(id: albumId)
        albumDeleted = true
    }

    func confirmAlbumDeletionCombinedOnly(album: Album) async {
        let pairIds = Set(album.pairIds)
        if !pairIds.isEmpty {
            try? await deleteCombinedExports(ids: pairIds)
        }
        try? await albumRepo.delete(id: albumId)
        albumDeleted = true
    }
}
