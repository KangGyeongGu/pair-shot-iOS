extension AlbumDetailViewModel {
    var pairCardActions: PairCardActions {
        PairCardActions(
            onShare: { pair in
                Task { await self.sharePair(pair) }
            },
            onExport: { pair in
                Task { await self.exportPair(pair) }
            },
            onRequestAfterDeletion: { pair in
                self.requestAfterDeletion(pair)
            },
            onRequestPairDeletion: { pair in
                self.requestSinglePairDeletion(pair)
            },
        )
    }
}
