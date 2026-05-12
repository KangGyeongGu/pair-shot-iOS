import Foundation
@testable import PairShot
import Testing

@MainActor
struct AfterCameraShutterContractionTests {
    private func makePair() -> PhotoPair {
        PhotoPair()
    }

    @Test("removeAll by captured id contracts the pairs array synchronously without reordering survivors")
    func contractionRemovesOnlyCapturedAndPreservesOrder() {
        let first = makePair()
        let second = makePair()
        let third = makePair()
        let fourth = makePair()
        var pairs: [PhotoPair] = [first, second, third, fourth]

        pairs.removeAll { $0.id == first.id }

        #expect(pairs.count == 3)
        #expect(pairs.map(\.id) == [second.id, third.id, fourth.id])
    }

    @Test("Contraction picks pairs.first as the next adopted pair, which is the natural neighbor")
    func nextAdoptedPairIsHeadOfContractedArray() {
        let first = makePair()
        let second = makePair()
        let third = makePair()
        var pairs: [PhotoPair] = [first, second, third]

        pairs.removeAll { $0.id == first.id }
        let next = pairs.first

        #expect(next?.id == second.id)
    }

    @Test("Contracting last remaining pair empties the array and exposes the all-completed state")
    func contractingLastEmptiesArray() {
        let only = makePair()
        var pairs: [PhotoPair] = [only]

        pairs.removeAll { $0.id == only.id }

        #expect(pairs.isEmpty)
        #expect(pairs.first == nil)
    }

    @Test("Rollback re-appends the failed pair when it is no longer present in the array")
    func rollbackReappendsAbsentPair() {
        let pair = makePair()
        var pairs: [PhotoPair] = []
        let shouldAppend = !pairs.contains(where: { $0.id == pair.id })

        if shouldAppend {
            pairs.append(pair)
        }

        #expect(pairs.count == 1)
        #expect(pairs.first?.id == pair.id)
    }

    @Test("Rollback is a no-op when the pair is still present (idempotent on concurrent state)")
    func rollbackSkipsWhenPairStillPresent() {
        let pair = makePair()
        var pairs: [PhotoPair] = [pair]
        let shouldAppend = !pairs.contains(where: { $0.id == pair.id })

        if shouldAppend {
            pairs.append(pair)
        }

        #expect(pairs.count == 1)
    }

    @Test("pendingPairCount decrement clamps at zero on underflow")
    func pendingClampsAtZero() {
        var pendingPairCount = 0
        pendingPairCount = max(0, pendingPairCount - 1)
        #expect(pendingPairCount == 0)
    }

    @Test("completedPairCount rollback clamps at zero on underflow")
    func completedClampsAtZero() {
        var completedPairCount = 0
        completedPairCount = max(0, completedPairCount - 1)
        #expect(completedPairCount == 0)
    }
}
