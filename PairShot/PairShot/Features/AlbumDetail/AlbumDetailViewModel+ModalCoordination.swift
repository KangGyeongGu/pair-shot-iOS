import Foundation

extension AlbumDetailViewModel {
    func requestPairDeletion(from all: [PhotoPair]) {
        let chosen = all.filter { selectedPairIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pendingPairDelete = AlbumDetailPairDeleteRequest(pairs: chosen)
    }

    func requestSinglePairDeletion(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingSinglePairDelete = AlbumDetailSinglePairDeleteRequest(pair: pair)
    }

    func requestRecaptureAfter(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingRecaptureAfter = AlbumDetailRecaptureAfterRequest(pair: pair)
    }

    func requestAlbumDeletion(album: Album) {
        pendingAlbumDelete = album
    }

    func startCapture() async {
        if !entitlement.isPaidPro {
            let count = await todayCreatedCountOrZero()
            guard count < PairLimitGate.freeTierDailyLimit else {
                showPaywall = true
                return
            }
        }
        beforeCameraTargetPairId = nil
        showBeforeCamera = true
    }

    func todayCreatedCountOrZero() async -> Int {
        let dayStart = PairLimitGate.startOfToday()
        return await (try? pairRepo.countCreated(since: dayStart)) ?? 0
    }
}
