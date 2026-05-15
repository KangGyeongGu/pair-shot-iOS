import Foundation

extension AlbumDetailViewModel {
    func sortedPairs(from pairs: [PhotoPair]) -> [PhotoPair] {
        switch sortOrder {
            case .newest:
                pairs.sorted { $0.createdAt > $1.createdAt }

            case .oldest:
                pairs.sorted { $0.createdAt < $1.createdAt }
        }
    }
}
