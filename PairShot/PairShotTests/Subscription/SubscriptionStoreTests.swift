import Foundation
@testable import PairShot
import StoreKit
import StoreKitTest
import Testing

@MainActor
struct SubscriptionStoreTests {
    @Test("refresh sets isPro = false when no entitlements exist")
    func refreshWithoutEntitlementsKeepsIsProFalse() async throws {
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

    @Test("Active monthly subscription with future expiration counts as pro")
    func activeMonthlyIsPro() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 30)
        )
        #expect(SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test("Active annual subscription with future expiration counts as pro")
    func activeAnnualIsPro() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proAnnual,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 365)
        )
        #expect(SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test("Subscription with nil expiration is treated as never-expiring pro")
    func nilExpirationIsPro() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: nil
        )
        #expect(SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test("Revoked transaction is not pro even when expiration is future")
    func revokedTransactionIsNotPro() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: now.addingTimeInterval(-60),
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 30)
        )
        #expect(!SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test("Expired transaction is not pro")
    func expiredTransactionIsNotPro() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(-1)
        )
        #expect(!SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test("Expiration exactly equal to now is not pro (strict greater-than)")
    func expirationEqualToNowIsNotPro() {
        let snapshot = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: now
        )
        #expect(!SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }

    @Test("Unknown product identifier is not pro even with future expiration")
    func unknownProductIsNotPro() {
        let snapshot = EntitlementSnapshot(
            productID: "app.pairshot.consumable.coin",
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60 * 60 * 24 * 30)
        )
        #expect(!SubscriptionStore.isActivePro(snapshot: snapshot, now: now))
    }
}

struct SubscriptionStatusPredicateTests {
    @Test("Subscribed renewal state with known product is pro")
    func subscribedStateIsPro() {
        let snapshot = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .subscribed)
        #expect(SubscriptionStore.isActiveProStatus(snapshot))
    }

    @Test("Grace period renewal state with known product is pro")
    func gracePeriodStateIsPro() {
        let snapshot = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .inGracePeriod)
        #expect(SubscriptionStore.isActiveProStatus(snapshot))
    }

    @Test("Billing retry renewal state with known product is pro")
    func billingRetryStateIsPro() {
        let snapshot = SubscriptionStatusSnapshot(productID: ProductIDs.proAnnual, state: .inBillingRetryPeriod)
        #expect(SubscriptionStore.isActiveProStatus(snapshot))
    }

    @Test("Expired renewal state is not pro")
    func expiredStateIsNotPro() {
        let snapshot = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .expired)
        #expect(!SubscriptionStore.isActiveProStatus(snapshot))
    }

    @Test("Revoked renewal state is not pro")
    func revokedStateIsNotPro() {
        let snapshot = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .revoked)
        #expect(!SubscriptionStore.isActiveProStatus(snapshot))
    }

    @Test("Unknown product with subscribed state is not pro")
    func unknownProductSubscribedIsNotPro() {
        let snapshot = SubscriptionStatusSnapshot(productID: "app.pairshot.unknown", state: .subscribed)
        #expect(!SubscriptionStore.isActiveProStatus(snapshot))
    }
}

struct SubscriptionComputeIsProTests {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test("computeIsPro returns true when entitlement active even if statuses empty")
    func entitlementOnlyGrantsPro() {
        let entitlement = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60 * 60)
        )
        let result = SubscriptionStore.computeIsPro(
            entitlements: [entitlement],
            statuses: [],
            now: now
        )
        #expect(result)
    }

    @Test("computeIsPro returns true when only status is in grace period (entitlement absent)")
    func gracePeriodWithoutEntitlementGrantsPro() {
        let status = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .inGracePeriod)
        let result = SubscriptionStore.computeIsPro(
            entitlements: [],
            statuses: [status],
            now: now
        )
        #expect(result)
    }

    @Test("computeIsPro returns true for billing retry status when entitlement expired")
    func billingRetryOverridesExpiredEntitlement() {
        let entitlement = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(-60)
        )
        let status = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .inBillingRetryPeriod)
        let result = SubscriptionStore.computeIsPro(
            entitlements: [entitlement],
            statuses: [status],
            now: now
        )
        #expect(result)
    }

    @Test("computeIsPro returns false when entitlement revoked and status revoked")
    func revokedEntitlementAndStatusYieldsNotPro() {
        let entitlement = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: now.addingTimeInterval(-60),
            expirationDate: now.addingTimeInterval(60 * 60)
        )
        let status = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .revoked)
        let result = SubscriptionStore.computeIsPro(
            entitlements: [entitlement],
            statuses: [status],
            now: now
        )
        #expect(!result)
    }

    @Test("computeIsPro returns false when entitlement and status both empty")
    func emptyInputsYieldNotPro() {
        let result = SubscriptionStore.computeIsPro(entitlements: [], statuses: [], now: now)
        #expect(!result)
    }
}
