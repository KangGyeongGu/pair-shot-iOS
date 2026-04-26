import AppTrackingTransparency
import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P6d (P6.7~P6.8 + ATT polish) — `BootstrapAdsCoordinator.bootstrap`
/// orchestrates the order:
///
///   AdFreeStore.refresh → ATT request (if undetermined and not adfree)
///   → load every ad surface
///
/// Pulled out of `PairShotApp` so the sequencing is unit-testable
/// without driving SwiftUI. Tests use `FakeTrackingAuthorizationProvider`
/// to assert the ATT prompt fires *exactly* once on undetermined and
/// *zero* times on already-decided / ad-free states.
@MainActor
final class ATTWiringTests: XCTestCase {
    /// Fake mirroring `TrackingAuthorizationProviding` — caller-driven
    /// status + counters so we can prove the wiring without a system
    /// foreground prompt.
    private final class FakeTrackingAuthorizationProvider: TrackingAuthorizationProviding,
        @unchecked Sendable
    {
        var status: ATTrackingManager.AuthorizationStatus
        var responseStatus: ATTrackingManager.AuthorizationStatus
        private(set) var requestCallCount = 0

        init(
            status: ATTrackingManager.AuthorizationStatus,
            responseStatus: ATTrackingManager.AuthorizationStatus? = nil
        ) {
            self.status = status
            self.responseStatus = responseStatus ?? status
        }

        var currentStatus: ATTrackingManager.AuthorizationStatus {
            status
        }

        func requestAuthorization() async -> ATTrackingManager.AuthorizationStatus {
            requestCallCount += 1
            status = responseStatus
            return responseStatus
        }
    }

    // MARK: - happy

    func testUndeterminedRequestsATTThenLoads() async throws {
        let fake = FakeTrackingAuthorizationProvider(
            status: .notDetermined,
            responseStatus: .authorized
        )
        let tracking = TrackingAuthorizationService(provider: fake)
        let container = try BootstrapTestSupport.makeContainer()
        let store = AdFreeStore(context: container.mainContext)
        XCTAssertFalse(store.isAdFree, "preflight: empty store must be non-ad-free")

        var loadCallCount = 0
        await BootstrapAdsCoordinator.bootstrap(
            adFreeStore: store,
            tracking: tracking,
            ifNotAdFree: { _ in loadCallCount += 1 }
        )

        XCTAssertEqual(fake.requestCallCount, 1, "ATT must be requested exactly once")
        XCTAssertEqual(loadCallCount, 1, "loads must fire after ATT returns")
        XCTAssertEqual(tracking.currentStatus, .authorized)
    }

    func testAlreadyAuthorizedSkipsRequestAndStillLoads() async throws {
        let fake = FakeTrackingAuthorizationProvider(status: .authorized)
        let tracking = TrackingAuthorizationService(provider: fake)
        let container = try BootstrapTestSupport.makeContainer()
        let store = AdFreeStore(context: container.mainContext)

        var loadCallCount = 0
        await BootstrapAdsCoordinator.bootstrap(
            adFreeStore: store,
            tracking: tracking,
            ifNotAdFree: { _ in loadCallCount += 1 }
        )

        XCTAssertEqual(fake.requestCallCount, 0, "ATT must not re-prompt when already decided")
        XCTAssertEqual(loadCallCount, 1, "loads must still fire when ATT was already authorized")
    }

    func testAlreadyDeniedSkipsRequestAndStillLoads() async throws {
        // Denied users still see ads (non-personalised). The bootstrap
        // must not re-prompt, but it must still load.
        let fake = FakeTrackingAuthorizationProvider(status: .denied)
        let tracking = TrackingAuthorizationService(provider: fake)
        let container = try BootstrapTestSupport.makeContainer()
        let store = AdFreeStore(context: container.mainContext)

        var loadCallCount = 0
        await BootstrapAdsCoordinator.bootstrap(
            adFreeStore: store,
            tracking: tracking,
            ifNotAdFree: { _ in loadCallCount += 1 }
        )

        XCTAssertEqual(fake.requestCallCount, 0)
        XCTAssertEqual(loadCallCount, 1)
    }

    // MARK: - edge

    func testAdFreeUserSkipsBothATTAndLoads() async throws {
        let fake = FakeTrackingAuthorizationProvider(status: .notDetermined)
        let tracking = TrackingAuthorizationService(provider: fake)
        let container = try BootstrapTestSupport.makeContainer()
        let store = AdFreeStore(context: container.mainContext)

        // Insert an active coupon so the store reports AdFree.
        let coupon = Coupon(
            code: "ADFREE",
            activatedAt: .now,
            durationDays: 30,
            signatureBase64: "sig"
        )
        container.mainContext.insert(coupon)
        try container.mainContext.save()
        store.refresh()
        XCTAssertTrue(store.isAdFree, "preflight: store must be ad-free for this test")

        var loadCallCount = 0
        await BootstrapAdsCoordinator.bootstrap(
            adFreeStore: store,
            tracking: tracking,
            ifNotAdFree: { _ in loadCallCount += 1 }
        )

        XCTAssertEqual(
            fake.requestCallCount, 0,
            "ATT prompt must not fire for ad-free users (CLAUDE.md core principle 7)"
        )
        XCTAssertEqual(loadCallCount, 0, "no ad load for ad-free users")
    }

    func testRepeatedBootstrapDoesNotRePromptATTAfterDecision() async throws {
        let fake = FakeTrackingAuthorizationProvider(
            status: .notDetermined,
            responseStatus: .denied
        )
        let tracking = TrackingAuthorizationService(provider: fake)
        let container = try BootstrapTestSupport.makeContainer()
        let store = AdFreeStore(context: container.mainContext)

        var loadCallCount = 0
        await BootstrapAdsCoordinator.bootstrap(
            adFreeStore: store,
            tracking: tracking,
            ifNotAdFree: { _ in loadCallCount += 1 }
        )
        await BootstrapAdsCoordinator.bootstrap(
            adFreeStore: store,
            tracking: tracking,
            ifNotAdFree: { _ in loadCallCount += 1 }
        )

        XCTAssertEqual(fake.requestCallCount, 1, "ATT must only be asked once across foregrounds")
        XCTAssertEqual(loadCallCount, 2, "load fires on both bootstraps regardless")
    }
}

/// Shared SwiftData container builder used by the Phase-6d test files.
/// Lives here (rather than in a Helpers/ folder) to keep the tests
/// directory flat — there's only the one helper.
enum BootstrapTestSupport {
    @MainActor
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
