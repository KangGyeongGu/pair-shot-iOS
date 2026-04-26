import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P8.5 — covers ``AdFreeCouponSorter`` plus the round-trip via the
/// ``AdFreeStore/activeCoupons`` / ``AdFreeStore/pastCoupons`` computed
/// properties, so the partition logic is locked even if the store later
/// adds caching.
@MainActor
final class AdFreeStoreSortingTests: XCTestCase {
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

    // MARK: - active — happy

    func testActiveOrdersByExpirationDescending() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let early = Coupon(
            code: "EARLY",
            activatedAt: now,
            durationDays: 7,
            signatureBase64: "x"
        )
        let mid = Coupon(
            code: "MID",
            activatedAt: now,
            durationDays: 30,
            signatureBase64: "x"
        )
        let late = Coupon(
            code: "LATE",
            activatedAt: now,
            durationDays: 365,
            signatureBase64: "x"
        )

        let sorted = AdFreeCouponSorter.active([early, late, mid], now: now)
        XCTAssertEqual(sorted.map(\.code), ["LATE", "MID", "EARLY"])
    }

    func testActiveExcludesExpiredAndRevoked() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let pastExpiration = now.addingTimeInterval(-86400)
        let goodFutureCoupon = Coupon(
            code: "GOOD",
            activatedAt: now,
            durationDays: 7,
            signatureBase64: "x"
        )
        let staleActive = Coupon(
            code: "STALE",
            activatedAt: pastExpiration.addingTimeInterval(-86400 * 30),
            durationDays: 1,
            signatureBase64: "x",
            status: .active
        )
        let revoked = Coupon(
            code: "REV",
            activatedAt: now,
            durationDays: 30,
            signatureBase64: "x",
            status: .revoked
        )
        let expired = Coupon(
            code: "EXP",
            activatedAt: now,
            durationDays: 30,
            signatureBase64: "x",
            status: .expired
        )

        let active = AdFreeCouponSorter.active(
            [goodFutureCoupon, staleActive, revoked, expired],
            now: now
        )
        XCTAssertEqual(active.map(\.code), ["GOOD"])
    }

    // MARK: - past — happy

    func testPastOrdersByActivatedAtDescending() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let oldest = Coupon(
            code: "OLD",
            activatedAt: now.addingTimeInterval(-86400 * 30),
            durationDays: 1,
            signatureBase64: "x",
            status: .expired
        )
        let middle = Coupon(
            code: "MID",
            activatedAt: now.addingTimeInterval(-86400 * 10),
            durationDays: 1,
            signatureBase64: "x",
            status: .expired
        )
        let newest = Coupon(
            code: "NEW",
            activatedAt: now.addingTimeInterval(-86400),
            durationDays: 0,
            signatureBase64: "x",
            status: .revoked
        )

        let past = AdFreeCouponSorter.past([oldest, newest, middle], now: now)
        XCTAssertEqual(past.map(\.code), ["NEW", "MID", "OLD"])
    }

    func testPastIncludesActiveButExpired() {
        // A coupon stuck at `.active` whose expiration is in the past
        // belongs to the "past" partition until `AdFreeStore.refresh()`
        // rolls it over.
        let now = Date(timeIntervalSince1970: 2_000_000)
        let stale = Coupon(
            code: "STALE",
            activatedAt: now.addingTimeInterval(-86400 * 30),
            durationDays: 1,
            signatureBase64: "x",
            status: .active
        )
        let past = AdFreeCouponSorter.past([stale], now: now)
        XCTAssertEqual(past.map(\.code), ["STALE"])
    }

    // MARK: - edge — partitions are disjoint

    func testActiveAndPastAreDisjointForSameInput() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let coupons: [Coupon] = [
            Coupon(code: "A", activatedAt: now, durationDays: 30, signatureBase64: "x"),
            Coupon(
                code: "B",
                activatedAt: now,
                durationDays: 30,
                signatureBase64: "x",
                status: .revoked
            ),
            Coupon(
                code: "C",
                activatedAt: now.addingTimeInterval(-86400 * 60),
                durationDays: 7,
                signatureBase64: "x",
                status: .active
            ),
        ]
        let active = AdFreeCouponSorter.active(coupons, now: now)
        let past = AdFreeCouponSorter.past(coupons, now: now)
        XCTAssertEqual(Set(active.map(\.code)).intersection(Set(past.map(\.code))), [])
        XCTAssertEqual(Set(active.map(\.code) + past.map(\.code)), ["A", "B", "C"])
    }

    // MARK: - integration with AdFreeStore

    func testStoreActiveCouponsReflectsActiveOrdering() throws {
        let early = Coupon(
            code: "EARLY",
            activatedAt: .now,
            durationDays: 7,
            signatureBase64: "x"
        )
        let late = Coupon(
            code: "LATE",
            activatedAt: .now,
            durationDays: 365,
            signatureBase64: "x"
        )
        context.insert(early)
        context.insert(late)
        try context.save()

        let store = AdFreeStore(context: context)
        XCTAssertEqual(store.activeCoupons.map(\.code), ["LATE", "EARLY"])
        XCTAssertTrue(store.pastCoupons.isEmpty)
    }

    func testStorePastCouponsExposesRevoked() throws {
        let revoked = Coupon(
            code: "REV",
            activatedAt: .now,
            durationDays: 30,
            signatureBase64: "x",
            status: .revoked
        )
        context.insert(revoked)
        try context.save()

        let store = AdFreeStore(context: context)
        XCTAssertTrue(store.activeCoupons.isEmpty)
        XCTAssertEqual(store.pastCoupons.map(\.code), ["REV"])
    }
}
