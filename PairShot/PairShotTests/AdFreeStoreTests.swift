import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P6.3 — `AdFreeStore` derives `isAdFree` from `Coupon` rows.
@MainActor
final class AdFreeStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        let schema = Schema([Project.self, PhotoPair.self, Coupon.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - happy

    func testEmptyStoreIsNotAdFree() {
        let store = AdFreeStore(context: context)
        XCTAssertFalse(store.isAdFree)
        XCTAssertNil(store.currentExpiration)
    }

    func testActiveCouponMakesAdFreeTrue() throws {
        let coupon = Coupon(
            code: "VALID",
            activatedAt: .now,
            durationDays: 30,
            signatureBase64: "AAAA"
        )
        context.insert(coupon)
        try context.save()

        let store = AdFreeStore(context: context)
        XCTAssertTrue(store.isAdFree)
        XCTAssertNotNil(store.currentExpiration)
    }

    func testExpirationDateMatchesLatestActiveCoupon() throws {
        let early = Coupon(
            code: "EARLY",
            activatedAt: Date(timeIntervalSince1970: 1_000),
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
        XCTAssertTrue(store.isAdFree)
        XCTAssertEqual(store.currentExpiration, late.expirationDate)
    }

    // MARK: - edge

    func testExpiredCouponDoesNotGrantAdFree() throws {
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: .now)!
        let stale = Coupon(
            code: "OLD",
            activatedAt: twoYearsAgo,
            durationDays: 30,
            signatureBase64: "AA"
        )
        context.insert(stale)
        try context.save()

        let store = AdFreeStore(context: context)
        XCTAssertFalse(store.isAdFree)
        XCTAssertNil(store.currentExpiration)
    }

    func testRevokedCouponDoesNotGrantAdFree() throws {
        let coupon = Coupon(
            code: "REVOKED",
            activatedAt: .now,
            durationDays: 30,
            signatureBase64: "AA",
            status: .revoked
        )
        context.insert(coupon)
        try context.save()

        let store = AdFreeStore(context: context)
        XCTAssertFalse(store.isAdFree)
    }

    func testExpiredActiveCouponIsRolledOverOnRefresh() throws {
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: .now)!
        let stale = Coupon(
            code: "OLD",
            activatedAt: twoYearsAgo,
            durationDays: 30,
            signatureBase64: "AA",
            status: .active // intentionally still .active to test rollover
        )
        context.insert(stale)
        try context.save()

        let store = AdFreeStore(context: context)
        store.refresh()

        // After refresh, the stale row should be flipped to .expired so
        // the next refresh is fast.
        XCTAssertEqual(stale.status, .expired)
    }

    func testRefreshPicksUpNewlyInsertedCoupon() throws {
        let store = AdFreeStore(context: context)
        XCTAssertFalse(store.isAdFree)

        let coupon = Coupon(
            code: "NEW",
            activatedAt: .now,
            durationDays: 30,
            signatureBase64: "AA"
        )
        context.insert(coupon)
        try context.save()
        store.refresh()

        XCTAssertTrue(store.isAdFree)
    }
}
