extension HomeViewModel {
    func tapAlbum(_ album: Album) {
        if isSelectionMode {
            toggleAlbumSelection(album.id)
        }
    }

    func requestPairDeletion(from all: [PhotoPair]) {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pendingPairDelete = HomePairDeleteRequest(pairs: chosen)
    }

    func requestAlbumDeletion(from all: [Album]) {
        let chosen = all.filter { selectedAlbumIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pendingAlbumDelete = HomeAlbumDeleteRequest(albums: chosen)
    }

    func requestSinglePairDeletion(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingSinglePairDelete = HomeSinglePairDeleteRequest(pair: pair)
    }

    func requestSingleAlbumDeletion(_ album: Album) {
        guard !isSelectionMode else { return }
        pendingSingleAlbumDelete = HomeSingleAlbumDeleteRequest(album: album)
    }
}
