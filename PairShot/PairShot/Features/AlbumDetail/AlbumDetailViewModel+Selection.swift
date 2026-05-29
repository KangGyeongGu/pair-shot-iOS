import Foundation

extension AlbumDetailViewModel {
    func enterSelectionMode() {
        guard !isSelectionMode else { return }
        isSelectionMode = true
    }

    func cancelSelection() {
        isSelectionMode = false
        selectedPairIds.removeAll()
    }

    func selectAllPairs(from all: [PhotoPair]) {
        let allIds = Set(all.map(\.id))
        selectedPairIds = selectedPairIds == allIds ? [] : allIds
    }

    func areAllPairsSelected(from all: [PhotoPair]) -> Bool {
        !all.isEmpty && selectedPairIds.count == all.count
    }

    func pruneStalePairSelections(currentIds: Set<UUID>) {
        guard !selectedPairIds.isEmpty else { return }
        let intersected = selectedPairIds.intersection(currentIds)
        if intersected.count != selectedPairIds.count {
            selectedPairIds = intersected
        }
    }
}
