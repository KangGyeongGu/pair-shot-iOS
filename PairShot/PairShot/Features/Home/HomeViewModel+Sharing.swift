import Foundation

extension HomeViewModel {
    func shareSelectedPairs(from all: [PhotoPair]) async {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        guard !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            promotionStore: membership.promotionStore,
            subscriptionStore: membership.subscriptionStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performShare(pairs: chosen)
        }
    }

    func saveSelectedPairsToDevice(from all: [PhotoPair]) async {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        guard !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            promotionStore: membership.promotionStore,
            subscriptionStore: membership.subscriptionStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performSaveToDevice(pairs: chosen)
        }
    }

    func shareSelectedAlbumPairs(from albums: [Album], allPairs: [PhotoPair]) async {
        let pairIds = Set(
            albums.filter { selectedAlbumIds.contains($0.id) }.flatMap(\.pairIds)
        )
        guard !pairIds.isEmpty else { return }
        let chosen = allPairs.filter { pairIds.contains($0.id) }
        guard !chosen.isEmpty, !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            promotionStore: membership.promotionStore,
            subscriptionStore: membership.subscriptionStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performShare(pairs: chosen)
        }
    }

    func saveSelectedAlbumPairsToDevice(from albums: [Album], allPairs: [PhotoPair]) async {
        let pairIds = Set(
            albums.filter { selectedAlbumIds.contains($0.id) }.flatMap(\.pairIds)
        )
        guard !pairIds.isEmpty else { return }
        let chosen = allPairs.filter { pairIds.contains($0.id) }
        guard !chosen.isEmpty, !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            promotionStore: membership.promotionStore,
            subscriptionStore: membership.subscriptionStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performSaveToDevice(pairs: chosen)
        }
    }

    func sharePair(_ pair: PhotoPair) async {
        guard !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            promotionStore: membership.promotionStore,
            subscriptionStore: membership.subscriptionStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performShare(pairs: [pair])
        }
    }

    func exportPair(_ pair: PhotoPair) async {
        guard !isExporting else { return }
        await InterstitialAdManager.runGated(
            manager: interstitialAdManager,
            promotionStore: membership.promotionStore,
            subscriptionStore: membership.subscriptionStore,
            coordinator: fullscreenAdCoordinator
        ) { [weak self] in
            await self?.performSaveToDevice(pairs: [pair])
        }
    }

    func handleZipExportCompleted(_ saved: Bool) {
        let url = pendingZipExport?.url
        let progress = pendingZipProgress
        pendingZipExport = nil
        pendingZipProgress = nil
        if let url, let progress {
            immediateExport.finishZipExport(url: url, progress: progress, saved: saved)
            cancelSelection()
        }
    }

    func clearShareItems() {
        if let items = pendingShareItems {
            immediateExport.cleanup(items: items)
        }
        pendingShareItems = nil
        cancelSelection()
    }

    func performShare(pairs: [PhotoPair]) async {
        isExporting = true
        defer { isExporting = false }
        do {
            let items = try await immediateExport.makeShareItems(for: pairs)
            guard !items.values.isEmpty else { return }
            pendingShareItems = items
        } catch {
            immediateExport.notifyShareFailure()
        }
    }

    func performSaveToDevice(pairs: [PhotoPair]) async {
        isExporting = true
        defer { isExporting = false }
        let outcome = await immediateExport.saveToDevice(pairs: pairs)
        switch outcome {
            case .completed:
                cancelSelection()

            case let .zipPendingExport(url, progress):
                pendingZipProgress = progress
                pendingZipExport = DocumentExporterItem(url: url)
        }
    }
}
