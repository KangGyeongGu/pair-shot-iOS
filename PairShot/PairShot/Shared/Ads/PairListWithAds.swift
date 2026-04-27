import Foundation

enum PairListItem: Identifiable, Hashable {
    case pair(PhotoPair)
    case ad(slotIndex: Int)

    var id: AnyHashable {
        switch self {
            case let .pair(pair):
                AnyHashable("pair-\(pair.id.uuidString)")

            case let .ad(slotIndex):
                AnyHashable("ad-\(slotIndex)")
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
            case let (.pair(left), .pair(right)):
                left.id == right.id

            case let (.ad(left), .ad(right)):
                left == right

            default:
                false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
            case let .pair(pair):
                hasher.combine(0)
                hasher.combine(pair.id)

            case let .ad(slotIndex):
                hasher.combine(1)
                hasher.combine(slotIndex)
        }
    }
}

enum PairListWithAdsBuilder {
    static let pairsPerAd = 4
    static let minPairsForAds = 3

    struct PairChunk: Identifiable {
        let id: Int
        let pairs: [PhotoPair]
        let adSlotIndex: Int?
    }

    struct ChunkResult {
        let chunks: [PairChunk]
        let nextSlotIndex: Int
    }

    static func buildChunks(
        pairs: [PhotoPair],
        adFree: Bool,
        startingAdSlotIndex: Int = 0
    ) -> ChunkResult {
        if adFree || pairs.count < minPairsForAds {
            let single = PairChunk(id: 0, pairs: pairs, adSlotIndex: nil)
            return ChunkResult(chunks: pairs.isEmpty ? [] : [single], nextSlotIndex: startingAdSlotIndex)
        }
        var chunks: [PairChunk] = []
        var slotIndex = startingAdSlotIndex
        var chunkIndex = 0
        var cursor = 0
        while cursor < pairs.count {
            let endExclusive = min(cursor + pairsPerAd, pairs.count)
            let segment = Array(pairs[cursor ..< endExclusive])
            let assignedAd = slotIndex
            slotIndex += 1
            chunks.append(PairChunk(id: chunkIndex, pairs: segment, adSlotIndex: assignedAd))
            chunkIndex += 1
            cursor = endExclusive
        }
        return ChunkResult(chunks: chunks, nextSlotIndex: slotIndex)
    }
}
