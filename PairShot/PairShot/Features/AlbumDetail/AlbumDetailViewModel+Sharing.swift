extension AlbumDetailViewModel: PairSharingHost {}

extension AlbumDetailViewModel {
    func shareSelectedPairs(from all: [PhotoPair]) async {
        await shareSelectedPairs(from: all, selectedIds: selectedPairIds)
    }

    func saveSelectedPairsToDevice(from all: [PhotoPair]) async {
        await saveSelectedPairsToDevice(from: all, selectedIds: selectedPairIds)
    }
}
