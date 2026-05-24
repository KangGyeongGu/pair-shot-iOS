extension HomeViewModel {
    var deletionCoordinator: PairDeletionCoordinator {
        PairDeletionCoordinator(
            deletePairs: deletePairs,
            deleteCombinedExports: deleteCombinedExports,
            deletePairsKeepingCombined: deletePairsKeepingCombined,
            thumbnailCache: thumbnailCache,
        )
    }

    func confirmPairDeletion(pairs: [PhotoPair]) async {
        await deletionCoordinator.deletePairsWithThumbnailEviction(pairs)
        cancelSelection()
    }

    func confirmCombinedDeletion(pairs: [PhotoPair]) async {
        await deletionCoordinator.deleteCombinedOnly(pairs)
        cancelSelection()
    }

    func confirmOriginalOnlyPairDeletion(pairs: [PhotoPair]) async {
        await deletionCoordinator.deleteOriginalsKeepingCombined(pairs)
        cancelSelection()
    }

    func confirmSinglePairDeletion(_ pair: PhotoPair) async {
        await deletionCoordinator.deleteSinglePairWithThumbnailEviction(pair)
    }

    func confirmSingleOriginalOnlyPairDeletion(_ pair: PhotoPair) async {
        await deletionCoordinator.deleteSingleOriginalKeepingCombined(pair)
    }

    func confirmSingleCombinedDeletion(_ pair: PhotoPair) async {
        await deletionCoordinator.deleteSingleCombinedOnly(pair)
    }

    func confirmAlbumDeletion(albums: [Album]) async {
        for album in albums {
            try? await albumRepo.delete(id: album.id)
        }
        cancelSelection()
    }

    func confirmAlbumDeletionAllPairs(albums: [Album]) async {
        let pairIds = Set(albums.flatMap(\.pairIds))
        if !pairIds.isEmpty {
            try? await deletePairs(ids: pairIds)
        }
        for album in albums {
            try? await albumRepo.delete(id: album.id)
        }
        cancelSelection()
    }

    func confirmAlbumDeletionOriginalOnly(albums: [Album]) async {
        let pairIds = Set(albums.flatMap(\.pairIds))
        if !pairIds.isEmpty {
            try? await deletePairsKeepingCombined(ids: pairIds)
        }
        for album in albums {
            try? await albumRepo.delete(id: album.id)
        }
        cancelSelection()
    }

    func confirmAlbumDeletionCombinedOnly(albums: [Album]) async {
        let pairIds = Set(albums.flatMap(\.pairIds))
        if !pairIds.isEmpty {
            try? await deleteCombinedExports(ids: pairIds)
        }
        for album in albums {
            try? await albumRepo.delete(id: album.id)
        }
        cancelSelection()
    }

    func confirmSingleAlbumDeletion(_ album: Album) async {
        try? await albumRepo.delete(id: album.id)
    }

    func confirmSingleAlbumDeletionAllPairs(_ album: Album) async {
        let pairIds = Set(album.pairIds)
        if !pairIds.isEmpty {
            try? await deletePairs(ids: pairIds)
        }
        try? await albumRepo.delete(id: album.id)
    }

    func confirmSingleAlbumDeletionOriginalOnly(_ album: Album) async {
        let pairIds = Set(album.pairIds)
        if !pairIds.isEmpty {
            try? await deletePairsKeepingCombined(ids: pairIds)
        }
        try? await albumRepo.delete(id: album.id)
    }

    func confirmSingleAlbumDeletionCombinedOnly(_ album: Album) async {
        let pairIds = Set(album.pairIds)
        if !pairIds.isEmpty {
            try? await deleteCombinedExports(ids: pairIds)
        }
        try? await albumRepo.delete(id: album.id)
    }
}
