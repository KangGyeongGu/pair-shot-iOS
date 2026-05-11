import Foundation

extension AlbumDetailViewModel {
    func confirmPairDeletion(pairs: [PhotoPair]) async {
        let snapshots: [(before: String?, after: String?)] = pairs.map {
            ($0.beforePhotoLocalIdentifier, $0.afterPhotoLocalIdentifier)
        }
        let ids = Set(pairs.map(\.id))
        try? await deletePairs(ids: ids)
        for snapshot in snapshots {
            evictThumbnails(beforeIdentifier: snapshot.before, afterIdentifier: snapshot.after)
        }
        cancelSelection()
    }

    func confirmOriginalOnlyDeletion(pairs: [PhotoPair]) async {
        guard let useCase = deletePairsKeepingCombined else { return }
        let snapshots: [(before: String?, after: String?)] = pairs.map {
            ($0.beforePhotoLocalIdentifier, $0.afterPhotoLocalIdentifier)
        }
        let ids = Set(pairs.map(\.id))
        try? await useCase(ids: ids)
        for snapshot in snapshots {
            evictThumbnails(beforeIdentifier: snapshot.before, afterIdentifier: snapshot.after)
        }
        cancelSelection()
    }

    func confirmSinglePairDeletion(_ pair: PhotoPair) async {
        let beforeId = pair.beforePhotoLocalIdentifier
        let afterId = pair.afterPhotoLocalIdentifier
        try? await deletePairs(ids: [pair.id])
        evictThumbnails(beforeIdentifier: beforeId, afterIdentifier: afterId)
    }

    func confirmSingleOriginalOnlyDeletion(_ pair: PhotoPair) async {
        guard let useCase = deletePairsKeepingCombined else { return }
        let beforeId = pair.beforePhotoLocalIdentifier
        let afterId = pair.afterPhotoLocalIdentifier
        try? await useCase(ids: [pair.id])
        evictThumbnails(beforeIdentifier: beforeId, afterIdentifier: afterId)
    }

    func confirmCombinedDeletion(pairs: [PhotoPair]) async {
        guard let useCase = deleteCombinedExports else { return }
        let ids = Set(pairs.map(\.id))
        try? await useCase(ids: ids)
        cancelSelection()
    }

    func confirmSingleCombinedDeletion(_ pair: PhotoPair) async {
        guard let useCase = deleteCombinedExports else { return }
        try? await useCase(ids: [pair.id])
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
        guard let useCase = deletePairsKeepingCombined else { return }
        let pairIds = Set(album.pairIds)
        if !pairIds.isEmpty {
            try? await useCase(ids: pairIds)
        }
        try? await albumRepo.delete(id: albumId)
        albumDeleted = true
    }

    func confirmAlbumDeletionCombinedOnly(album: Album) async {
        if let useCase = deleteCombinedExports {
            let pairIds = Set(album.pairIds)
            if !pairIds.isEmpty {
                try? await useCase(ids: pairIds)
            }
        }
        try? await albumRepo.delete(id: albumId)
        albumDeleted = true
    }

    func evictThumbnails(beforeIdentifier: String?, afterIdentifier: String?) {
        if let beforeIdentifier {
            thumbnailCache.evict(localIdentifier: beforeIdentifier)
        }
        if let afterIdentifier {
            thumbnailCache.evict(localIdentifier: afterIdentifier)
        }
    }
}
