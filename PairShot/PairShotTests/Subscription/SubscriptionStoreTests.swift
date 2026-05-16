import Foundation
@testable import PairShot
import StoreKit
import StoreKitTest
import Testing

@MainActor
struct SubscriptionStoreTests {
    @Test
    func `refresh sets isPro = false when no entitlements exist`() async throws {
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        session.disableDialogs = true
        session.clearTransactions()

        let store = SubscriptionStore()
        await store.refresh()

        #expect(store.isPro == false)
        _ = session
    }
}

struct SubscriptionEntitlementPredicateTests {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test
    func `Active monthly subscription with future expiration counts as pro`() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 30),
        )
        #expect(SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test
    func `Active annual subscription with future expiration counts as pro`() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proAnnual,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 365),
        )
        #expect(SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test
    func `Subscription with nil expiration is treated as never-expiring pro`() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: nil,
        )
        #expect(SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test
    func `Revoked transaction is not pro even when expiration is future`() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: now.addingTimeInterval(-60),
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 30),
        )
        #expect(!SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test
    func `Expired transaction is not pro`() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(-1),
        )
        #expect(!SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test
    func `Expiration exactly equal to now is not pro (strict greater-than)`() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: now,
        )
        #expect(!SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test
    func `Unknown product identifier is not pro even with future expiration`() {
        let snapshot = EntitlementSnapshot(
            productID: "app.pairshot.consumable.coin",
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 30),
        )
        #expect(!SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }
}

struct SubscriptionStatusPredicateTests {
    @Test
    func `Subscribed renewal state with known product is pro`() {
        let snapshot = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .subscribed)
        #expect(SubscriptionStore.isActiveProStatus(snapshot))
    }

    @Test
    func `Grace period renewal state with known product is pro`() {
        let snapshot = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .inGracePeriod)
        #expect(SubscriptionStore.isActiveProStatus(snapshot))
    }

    @Test
    func `Billing retry renewal state with known product is pro`() {
        let snapshot = SubscriptionStatusSnapshot(productID: ProductIDs.proAnnual, state: .inBillingRetryPeriod)
        #expect(SubscriptionStore.isActiveProStatus(snapshot))
    }

    @Test
    func `Expired renewal state is not pro`() {
        let snapshot = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .expired)
        #expect(!SubscriptionStore.isActiveProStatus(snapshot))
    }

    @Test
    func `Revoked renewal state is not pro`() {
        let snapshot = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .revoked)
        #expect(!SubscriptionStore.isActiveProStatus(snapshot))
    }

    @Test
    func `Unknown product with subscribed state is not pro`() {
        let snapshot = SubscriptionStatusSnapshot(productID: "app.pairshot.unknown", state: .subscribed)
        #expect(!SubscriptionStore.isActiveProStatus(snapshot))
    }
}

struct SubscriptionComputeIsProTests {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test
    func `computeIsPro returns true when entitlement active even if statuses empty`() {
        let entitlement = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60 * 60),
        )
        let result = SubscriptionStore.computeIsPro(
            entitlements: [entitlement],
            statuses: [],
            now: now,
        )
        #expect(result)
    }

    @Test
    func `computeIsPro returns true when only status is in grace period (entitlement absent)`() {
        let status = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .inGracePeriod)
        let result = SubscriptionStore.computeIsPro(
            entitlements: [],
            statuses: [status],
            now: now,
        )
        #expect(result)
    }

    @Test
    func `computeIsPro returns true for billing retry status when entitlement expired`() {
        let entitlement = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(-60),
        )
        let status = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .inBillingRetryPeriod)
        let result = SubscriptionStore.computeIsPro(
            entitlements: [entitlement],
            statuses: [status],
            now: now,
        )
        #expect(result)
    }

    @Test
    func `computeIsPro returns false when entitlement revoked and status revoked`() {
        let entitlement = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: now.addingTimeInterval(-60),
            expirationDate: now.addingTimeInterval(60 * 60),
        )
        let status = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .revoked)
        let result = SubscriptionStore.computeIsPro(
            entitlements: [entitlement],
            statuses: [status],
            now: now,
        )
        #expect(!result)
    }

    @Test
    func `computeIsPro returns false when entitlement and status both empty`() {
        let result = SubscriptionStore.computeIsPro(entitlements: [], statuses: [], now: now)
        #expect(!result)
    }
}
