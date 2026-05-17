import Foundation

extension HomeViewModel {
    func enterSelectionMode() {
        guard !isSelectionMode else { return }
        isSelectionMode = true
        selectedPairIds.removeAll()
        selectedAlbumIds.removeAll()
    }

    func enterSelectionMode(autoSelectingPairIds ids: [UUID]) {
        guard !isSelectionMode else { return }
        isSelectionMode = true
        selectedPairIds = Set(ids)
        selectedAlbumIds.removeAll()
    }

    func cancelSelection() {
        isSelectionMode = false
        selectedPairIds.removeAll()
        selectedAlbumIds.removeAll()
    }

    func togglePairSelection(_ id: UUID) {
        if selectedPairIds.contains(id) {
            selectedPairIds.remove(id)
        } else {
            selectedPairIds.insert(id)
        }
    }

    func toggleAlbumSelection(_ id: UUID) {
        if selectedAlbumIds.contains(id) {
            selectedAlbumIds.remove(id)
        } else {
            selectedAlbumIds.insert(id)
        }
    }

    func selectAllPairs(from all: [PhotoPair]) {
        let allIds = Set(all.map(\.id))
        selectedPairIds = selectedPairIds == allIds ? [] : allIds
    }

    func selectAllAlbums(from all: [Album]) {
        let allIds = Set(all.map(\.id))
        selectedAlbumIds = selectedAlbumIds == allIds ? [] : allIds
    }

    func areAllPairsSelected(from all: [PhotoPair]) -> Bool {
        !all.isEmpty && selectedPairIds.count == all.count
    }

    func areAllAlbumsSelected(from all: [Album]) -> Bool {
        !all.isEmpty && selectedAlbumIds.count == all.count
    }

    func switchContentMode(to mode: HomeContentMode) {
        guard mode != contentMode else { return }
        contentMode = mode
        cancelSelection()
    }

    func pruneStalePairSelections(currentIds: Set<UUID>) {
        guard !selectedPairIds.isEmpty else { return }
        let intersected = selectedPairIds.intersection(currentIds)
        if intersected.count != selectedPairIds.count {
            selectedPairIds = intersected
        }
    }

    func pruneStaleAlbumSelections(currentIds: Set<UUID>) {
        guard !selectedAlbumIds.isEmpty else { return }
        let intersected = selectedAlbumIds.intersection(currentIds)
        if intersected.count != selectedAlbumIds.count {
            selectedAlbumIds = intersected
        }
    }
}
