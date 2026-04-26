import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P6.7 — `RewardedSessionGate.shouldShowGate(...)` is the pure decision
/// `CompositionSettingsGate` consults to decide whether to render the
/// lock screen vs the gated child.
///
/// Three independent inputs (unlockID · sessionUnlocks · isAdFree)
/// produce a binary decision. We exercise each axis in isolation plus
/// the "1 watch per session" rule end-to-end via `RewardedAdManager`.
@MainActor
final class RewardedAdGateTests: XCTestCase {
    // MARK: - happy

    func testNonAdFreeUserWithEmptyUnlocksSeesGate() {
        XCTAssertTrue(
            RewardedSessionGate.shouldShowGate(
                unlockID: .compositionSettings,
                sessionUnlocks: [],
                isAdFree: false
            )
        )
    }

    func testNonAdFreeUserAfterUnlockBypassesGate() {
        XCTAssertFalse(
            RewardedSessionGate.shouldShowGate(
                unlockID: .compositionSettings,
                sessionUnlocks: [.compositionSettings],
                isAdFree: false
            )
        )
    }

    func testAdFreeUserNeverSeesGate() {
        XCTAssertFalse(
            RewardedSessionGate.shouldShowGate(
                unlockID: .compositionSettings,
                sessionUnlocks: [],
                isAdFree: true
            )
        )
    }

    func testAdFreeAndUnlockedStillBypassesGate() {
        // Two reasons to skip — combined still skips.
        XCTAssertFalse(
            RewardedSessionGate.shouldShowGate(
                unlockID: .compositionSettings,
                sessionUnlocks: [.compositionSettings],
                isAdFree: true
            )
        )
    }

    // MARK: - manager session-unlock semantics

    func testManagerSkippedAdFreePathInsertsUnlock() async throws {
        let manager = RewardedAdManager()
        let coordinator = FullscreenAdCoordinator()

        let container = try BootstrapTestSupport.makeContainer()
        let store = AdFreeStore(context: container.mainContext)
        let coupon = Coupon(
            code: "ADFREE",
            activatedAt: .now,
            durationDays: 30,
            signatureBase64: "sig"
        )
        container.mainContext.insert(coupon)
        try? container.mainContext.save()
        store.refresh()
        XCTAssertTrue(store.isAdFree, "preflight: store must be ad-free for this test")

        let outcome = await manager.presentForReward(
            .compositionSettings,
            from: nil,
            coordinator: coordinator,
            adFreeStore: store
        )
        XCTAssertEqual(outcome, .skipped(adFree: true))
        XCTAssertTrue(manager.sessionUnlocks.contains(.compositionSettings))
        XCTAssertFalse(
            RewardedSessionGate.shouldShowGate(
                unlockID: .compositionSettings,
                sessionUnlocks: manager.sessionUnlocks,
                isAdFree: true
            )
        )
    }

    func testManagerAlreadyUnlockedReturnsGrantedWithoutPresenting() async {
        let manager = RewardedAdManager()
        let coordinator = FullscreenAdCoordinator()
        manager.grantUnlockForTesting(.compositionSettings)

        let outcome = await manager.presentForReward(
            .compositionSettings,
            from: nil,
            coordinator: coordinator
        )
        XCTAssertEqual(outcome, .granted)
        // Coordinator must not be held — no presentation actually
        // happened.
        let isShowing = await coordinator.isShowing
        XCTAssertFalse(isShowing)
    }

    func testManagerResetClearsUnlocks() {
        let manager = RewardedAdManager()
        manager.grantUnlockForTesting(.compositionSettings)
        XCTAssertFalse(manager.sessionUnlocks.isEmpty)
        manager.resetSessionUnlocksForTesting()
        XCTAssertTrue(manager.sessionUnlocks.isEmpty)
    }
}
