import Foundation

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
        startingAdSlotIndex: Int = 0
    ) -> ChunkResult {
        if pairs.count < minPairsForAds {
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
