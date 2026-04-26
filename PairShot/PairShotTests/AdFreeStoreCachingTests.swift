import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// Audit-C — `AdFreeStore.activeCoupons` / `pastCoupons` are now stored
/// snapshots refreshed alongside `isAdFree` instead of computed
/// properties that re-fetch on every access.
///
/// This file pins the new contract:
/// 1. After `init`, the snapshots reflect the on-disk state.
/// 2. After `refresh()`, newly inserted coupons appear in
///    `activeCoupons` without an extra fetch.
/// 3. `activeCoupons` access does not perform a SwiftData fetch
///    (verified indirectly by inserting a row *without* refresh and
///    asserting the snapshot stayed cold).
@MainActor
final class AdFreeStoreCachingTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - happy

    func testInitSeedsEmptyActiveAndPastSnapshots() {
        let store = AdFreeStore(context: context)
        XCTAssertTrue(store.activeCoupons.isEmpty)
        XCTAssertTrue(store.pastCoupons.isEmpty)
    }

    func testRefreshPopulatesActiveSnapshot() throws {
        let coupon = Coupon(
            code: "ACTIVE-1",
            activatedAt: .now,
            durationDays: 30,
            signatureBase64: "AA"
        )
        context.insert(coupon)
        try context.save()

        let store = AdFreeStore(context: context)
        XCTAssertEqual(store.activeCoupons.count, 1)
        XCTAssertEqual(store.activeCoupons.first?.code, "ACTIVE-1")
        XCTAssertTrue(store.pastCoupons.isEmpty)
    }

    func testRefreshPopulatesPastSnapshotForExpiredCoupon() throws {
        let twoYearsAgo = try XCTUnwrap(Calendar.current.date(byAdding: .year, value: -2, to: .now))
        let stale = Coupon(
            code: "EXPIRED",
            activatedAt: twoYearsAgo,
            durationDays: 30,
            signatureBase64: "AA"
        )
        context.insert(stale)
        try context.save()

        let store = AdFreeStore(context: context)
        XCTAssertTrue(store.activeCoupons.isEmpty)
        XCTAssertEqual(store.pastCoupons.count, 1)
        XCTAssertEqual(store.pastCoupons.first?.code, "EXPIRED")
    }

    // MARK: - cache invariants

    func testNewlyInsertedCouponDoesNotAppearWithoutExplicitRefresh() throws {
        // Init snapshot is empty.
        let store = AdFreeStore(context: context)
        XCTAssertTrue(store.activeCoupons.isEmpty)

        // Insert a row WITHOUT calling refresh — the snapshot should
        // stay empty (proves activeCoupons is a stored snapshot, not a
        // hot fetch).
        let coupon = Coupon(
            code: "STEALTH",
            activatedAt: .now,
            durationDays: 30,
            signatureBase64: "AA"
        )
        context.insert(coupon)
        try context.save()

        XCTAssertTrue(
            store.activeCoupons.isEmpty,
            "snapshot must not auto-refresh on access — got \(store.activeCoupons.count)"
        )

        // After explicit refresh the new row appears.
        store.refresh()
        XCTAssertEqual(store.activeCoupons.count, 1)
    }

    func testRefreshOrdersActiveCouponsByExpirationDescending() throws {
        let early = Coupon(
            code: "EARLY",
            activatedAt: Date(timeIntervalSince1970: 1000),
            durationDays: 7,
            signatureBase64: "AA"
        )
        let late = Coupon(
            code: "LATE",
            activatedAt: .now,
            durationDays: 365,
            signatureBase64: "BB"
        )
        context.insert(early)
        context.insert(late)
        try context.save()

        let store = AdFreeStore(context: context)
        // Early coupon has long since expired (1970 + 7 days), so the
        // sorted output of active should be [late] only.
        XCTAssertEqual(store.activeCoupons.map(\.code), ["LATE"])
        XCTAssertEqual(store.pastCoupons.map(\.code), ["EARLY"])
    }
}
