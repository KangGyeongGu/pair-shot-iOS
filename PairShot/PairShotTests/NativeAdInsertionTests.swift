import Foundation
@testable import PairShot
import XCTest

/// P6.8 — `NativeAdInsertionStrategy.indices(...)` is the pure transform
/// the gallery uses to decide which 0-based slot offsets become native-
/// ad cells. The gallery view is rendered inside a SwiftUI `LazyVGrid`
/// so any subtle off-by-one here spawns visible regression. Pin the
/// behaviour with concrete examples.
final class NativeAdInsertionTests: XCTestCase {
    // MARK: - happy

    func testFourteenPairsAtIntervalSixYieldsTwoSlots() {
        // 14 pairs → first ad after the 6th pair (index 5), second
        // after the 12th (index 11). 14 < 18 so no third slot.
        XCTAssertEqual(
            NativeAdInsertionStrategy.indices(forPairCount: 14),
            [5, 11]
        )
    }

    func testEighteenPairsYieldsThreeSlots() {
        XCTAssertEqual(
            NativeAdInsertionStrategy.indices(forPairCount: 18),
            [5, 11, 17]
        )
    }

    func testSinglePairYieldsNoSlot() {
        XCTAssertEqual(
            NativeAdInsertionStrategy.indices(forPairCount: 1),
            []
        )
    }

    func testFivePairsYieldsNoSlot() {
        // Insertion index would be 5 but list only has 5 entries
        // (indices 0..<5) — no ad slot.
        XCTAssertEqual(
            NativeAdInsertionStrategy.indices(forPairCount: 5),
            []
        )
    }

    func testSixPairsYieldsExactlyOneSlotAtTheEnd() {
        // Boundary: the 6th pair is index 5 → first ad slot fires
        // exactly at the end of the run.
        XCTAssertEqual(
            NativeAdInsertionStrategy.indices(forPairCount: 6),
            [5]
        )
    }

    // MARK: - edge

    func testZeroPairsYieldsNoSlots() {
        XCTAssertEqual(
            NativeAdInsertionStrategy.indices(forPairCount: 0),
            []
        )
    }

    func testNegativePairCountYieldsNoSlots() {
        XCTAssertEqual(
            NativeAdInsertionStrategy.indices(forPairCount: -3),
            []
        )
    }

    func testIntervalOfZeroYieldsNoSlots() {
        // Defensive against settings glitches — interval ≤ 0 must not
        // crash or spin (would be `slot += 0` infinite loop).
        XCTAssertEqual(
            NativeAdInsertionStrategy.indices(forPairCount: 100, interval: 0),
            []
        )
    }

    func testNegativeIntervalYieldsNoSlots() {
        XCTAssertEqual(
            NativeAdInsertionStrategy.indices(forPairCount: 100, interval: -2),
            []
        )
    }

    func testCustomIntervalThree() {
        // Make sure the formula generalises beyond the default 6.
        XCTAssertEqual(
            NativeAdInsertionStrategy.indices(forPairCount: 10, interval: 3),
            [2, 5, 8]
        )
    }

    @MainActor
    func testRoundRobinPoolBehaviour() {
        // Document the loader's round-robin contract: with N=2 ads
        // loaded, slot index 0/2/4 → ad 0, slot 1/3/5 → ad 1.
        let loader = NativeAdLoader()
        let stub0 = "ad-0" as NSString
        let stub1 = "ad-1" as NSString
        loader.injectAdsForTesting([stub0, stub1])
        XCTAssertIdentical(loader.adFor(index: 0) as AnyObject, stub0)
        XCTAssertIdentical(loader.adFor(index: 1) as AnyObject, stub1)
        XCTAssertIdentical(loader.adFor(index: 2) as AnyObject, stub0)
        XCTAssertIdentical(loader.adFor(index: 5) as AnyObject, stub1)
    }

    @MainActor
    func testRoundRobinReturnsNilWhenPoolEmpty() {
        let loader = NativeAdLoader()
        loader.resetForTesting()
        XCTAssertNil(loader.adFor(index: 0))
        XCTAssertNil(loader.adFor(index: 99))
    }
}
