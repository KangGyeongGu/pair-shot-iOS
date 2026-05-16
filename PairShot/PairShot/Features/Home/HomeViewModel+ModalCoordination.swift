import Foundation

extension HomeViewModel {
    func tapPair(_ pair: PhotoPair, allPairs _: [PhotoPair]) {
        if isSelectionMode {
            togglePairSelection(pair.id)
            return
        }
        switch pair.status {
            case .afterOnly:
                beforeCameraTargetPairId = pair.id
                showBeforeCamera = true

            case .scheduled:
                afterCameraTargetPairId = pair.id
                showAfterCamera = true

            case .captured:
                pendingPreviewPair = HomePairPreviewRequest(pair: pair)
        }
    }

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

    func requestRecaptureAfter(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        pendingRecaptureAfter = HomeRecaptureAfterRequest(pair: pair)
    }

    func requestSingleAlbumDeletion(_ album: Album) {
        guard !isSelectionMode else { return }
        pendingSingleAlbumDelete = HomeSingleAlbumDeleteRequest(album: album)
    }

    func startCapture() async {
        if !membership.proIsActive {
            let count = await todayCreatedCountOrZero()
            guard count < PairLimitGate.freeTierDailyLimit else {
                snackbarQueue.enqueue(
                    "settings_promotion_guide_daily_limit",
                    variant: .info,
                    debounceKey: "pro_gate_daily_limit"
                )
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
