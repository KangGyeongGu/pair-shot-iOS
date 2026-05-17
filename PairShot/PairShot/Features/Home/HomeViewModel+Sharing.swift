import Foundation

extension HomeViewModel: PairSharingHost {}

extension HomeViewModel {
    func shareSelectedPairs(from all: [PhotoPair]) async {
        await shareSelectedPairs(from: all, selectedIds: selectedPairIds)
    }

    func saveSelectedPairsToDevice(from all: [PhotoPair]) async {
        await saveSelectedPairsToDevice(from: all, selectedIds: selectedPairIds)
    }

    func shareSelectedAlbumPairs(from albums: [Album], allPairs: [PhotoPair]) async {
        let pairIds = Set(
            albums.filter { selectedAlbumIds.contains($0.id) }.flatMap(\.pairIds),
        )
        guard !pairIds.isEmpty else { return }
        let chosen = allPairs.filter { pairIds.contains($0.id) }
        guard !chosen.isEmpty, !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            promotionStore: membership.promotionStore,
            subscriptionStore: membership.subscriptionStore,
            coordinator: fullscreenAdCoordinator,
        ) { [weak self] in
            await self?.performShare(pairs: chosen)
        }
    }

    func saveSelectedAlbumPairsToDevice(from albums: [Album], allPairs: [PhotoPair]) async {
        let pairIds = Set(
            albums.filter { selectedAlbumIds.contains($0.id) }.flatMap(\.pairIds),
        )
        guard !pairIds.isEmpty else { return }
        let chosen = allPairs.filter { pairIds.contains($0.id) }
        guard !chosen.isEmpty, !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            promotionStore: membership.promotionStore,
            subscriptionStore: membership.subscriptionStore,
            coordinator: fullscreenAdCoordinator,
        ) { [weak self] in
            await self?.performSaveToDevice(pairs: chosen)
        }
    }
}
