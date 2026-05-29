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

    func requestAfterDeletion(_ pair: PhotoPair) {
        guard !isSelectionMode else { return }
        guard pair.afterPhotoLocalIdentifier != nil else { return }
        pendingAfterDelete = PairAfterDeleteRequest(pair: pair)
    }

    func confirmAfterDeletion(_ pair: PhotoPair) async {
        _ = try? await deleteAfterPhoto(pairId: pair.id)
        if let afterId = pair.afterPhotoLocalIdentifier {
            thumbnailCache.evict(localIdentifier: afterId)
        }
    }

    func requestAlbumDeletion(album: Album) {
        pendingAlbumDelete = album
    }

    func startCapture() async {
        if !membership.proIsActive {
            let count = await todayCreatedCountOrZero()
            guard count < PairLimitGate.freeTierDailyLimit else {
                snackbarQueue.enqueue(
                    .dailyLimitGate,
                    debounceKey: "pro_gate_daily_limit",
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
