import Foundation

@MainActor
protocol PairGridHost: PairSharingHost {
    var isSelectionMode: Bool { get set }
    var selectedPairIds: Set<UUID> { get set }
    var pendingPreviewPair: PairPreviewRequest? { get set }
    var pendingAfterDelete: PairAfterDeleteRequest? { get set }
    var beforeCameraTargetPairId: UUID? { get set }
    var afterCameraTargetPairId: UUID? { get set }
    var showBeforeCamera: Bool { get set }
    var showAfterCamera: Bool { get set }

    var deleteAfterPhoto: DeleteAfterPhotoUseCase { get }
    var thumbnailCache: PhotoLibraryThumbnailCache { get }

    func requestSinglePairDeletion(_ pair: PhotoPair)
}

extension PairGridHost {
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

    func togglePairSelection(_ id: UUID) {
        if selectedPairIds.contains(id) {
            selectedPairIds.remove(id)
        } else {
            selectedPairIds.insert(id)
        }
    }

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
                pendingPreviewPair = PairPreviewRequest(pair: pair)
        }
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
}
