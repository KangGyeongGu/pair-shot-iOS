import Foundation
@testable import PairShot
import XCTest

/// P6c (P6.9 partial) — `FullscreenAdCoordinator` serialises fullscreen
/// ad presentations so an Interstitial / App Open / Rewarded never
/// stomps on each other.
///
/// These tests assert the actor-isolated `tryAcquire` / `release`
/// contract directly. Concurrency tests use `Task` groups to exercise
/// the race condition the actor is meant to prevent.
final class FullscreenAdCoordinatorTests: XCTestCase {
    // MARK: - happy

    func testInitialStateIsNotShowing() async {
        let coordinator = FullscreenAdCoordinator()
        let isShowing = await coordinator.isShowing
        XCTAssertFalse(isShowing)
    }

    func testTryAcquireSucceedsWhenIdle() async {
        let coordinator = FullscreenAdCoordinator()
        let acquired = await coordinator.tryAcquire()
        XCTAssertTrue(acquired)
        let isShowing = await coordinator.isShowing
        XCTAssertTrue(isShowing)
    }

    func testReleaseFlipsBackToIdle() async {
        let coordinator = FullscreenAdCoordinator()
        _ = await coordinator.tryAcquire()
        await coordinator.release()
        let isShowing = await coordinator.isShowing
        XCTAssertFalse(isShowing)
    }

    func testReacquireAfterReleaseSucceeds() async {
        let coordinator = FullscreenAdCoordinator()
        _ = await coordinator.tryAcquire()
        await coordinator.release()
        let second = await coordinator.tryAcquire()
        XCTAssertTrue(second)
    }

    // MARK: - edge

    func testTryAcquireFailsWhileShowing() async {
        let coordinator = FullscreenAdCoordinator()
        _ = await coordinator.tryAcquire()
        let denied = await coordinator.tryAcquire()
        XCTAssertFalse(denied, "second concurrent acquire must be rejected")
        // Slot remains held — only the original owner can release it.
        let isShowing = await coordinator.isShowing
        XCTAssertTrue(isShowing)
    }

    func testReleaseWithoutAcquireIsIdempotent() async {
        let coordinator = FullscreenAdCoordinator()
        // Should not crash / trip a precondition. Mirrors the GADFullScreen
        // delegate-callback ordering quirk noted in production code.
        await coordinator.release()
        await coordinator.release()
        let isShowing = await coordinator.isShowing
        XCTAssertFalse(isShowing)
    }

    func testConcurrentTryAcquireGrantsExactlyOne() async {
        let coordinator = FullscreenAdCoordinator()
        // Spin up 8 concurrent acquirers. Exactly one should win.
        let results = await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 8 {
                group.addTask { await coordinator.tryAcquire() }
            }
            var collected: [Bool] = []
            for await success in group {
                collected.append(success)
            }
            return collected
        }
        let winners = results.count(where: { $0 })
        XCTAssertEqual(winners, 1, "actor must serialise concurrent acquires")
    }
}
