import Foundation
@testable import PairShot
import StoreKit
import Testing
import UserNotifications

@MainActor
struct RenewalReminderSchedulerTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private static let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
    private static let oneDay: TimeInterval = 60 * 60 * 24

    @Test("Expiration 8 days from now yields trigger date 1 day from now")
    func expirationEightDaysAheadProducesTrigger() {
        let expiration = Self.now.addingTimeInterval(Self.oneDay * 8)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: Self.now,
            calendar: Self.calendar
        )
        let unwrapped = try? #require(result)
        let delta = unwrapped?.timeIntervalSince(Self.now) ?? 0
        #expect(abs(delta - Self.oneDay) < 60)
    }

    @Test("Expiration exactly 7 days from now yields nil (trigger == now, not strictly after)")
    func expirationSevenDaysAheadProducesNil() {
        let expiration = Self.now.addingTimeInterval(Self.oneDay * 7)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: Self.now,
            calendar: Self.calendar
        )
        #expect(result == nil)
    }

    @Test("Expiration 6 days from now yields nil (lead window already passed)")
    func expirationSixDaysAheadProducesNil() {
        let expiration = Self.now.addingTimeInterval(Self.oneDay * 6)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: Self.now,
            calendar: Self.calendar
        )
        #expect(result == nil)
    }

    @Test("Past expiration date yields nil")
    func pastExpirationProducesNil() {
        let expiration = Self.now.addingTimeInterval(-Self.oneDay)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: Self.now,
            calendar: Self.calendar
        )
        #expect(result == nil)
    }

    @Test("Far-future expiration (annual subscription) yields trigger 358 days from now")
    func annualExpirationProducesFarFutureTrigger() {
        let expiration = Self.now.addingTimeInterval(Self.oneDay * 365)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: Self.now,
            calendar: Self.calendar
        )
        let unwrapped = try? #require(result)
        let delta = unwrapped?.timeIntervalSince(Self.now) ?? 0
        #expect(abs(delta - Self.oneDay * 358) < 60)
    }

    @Test("DST boundary: spring-forward calendar still produces 7-day-before trigger")
    func dstBoundaryStillProducesTrigger() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
        let components = DateComponents(year: 2026, month: 3, day: 15, hour: 12)
        guard let expiration = calendar.date(from: components) else {
            Issue.record("Failed to construct DST expiration date")
            return
        }
        let now = expiration.addingTimeInterval(-Self.oneDay * 8)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: now,
            calendar: calendar
        )
        let unwrapped = try? #require(result)
        let delta = unwrapped?.timeIntervalSince(now) ?? 0
        #expect(delta > Self.oneDay * 0.9)
        #expect(delta < Self.oneDay * 1.1)
    }

    @Test("Identifier prefix uses fixed namespace + product ID")
    func identifierUsesPrefixedProductID() {
        let identifier = RenewalReminderScheduler.identifier(for: ProductIDs.proMonthly)
        #expect(identifier == "renewal_reminder_\(ProductIDs.proMonthly)")
        #expect(identifier.hasPrefix(RenewalReminderScheduler.identifierPrefix))
    }

    @Test("makeContent populates title, body, and default sound")
    func contentHasTitleBodyAndSound() {
        let content = RenewalReminderScheduler.makeContent(productDisplayName: "PairShot Pro")
        #expect(!content.title.isEmpty)
        #expect(!content.body.isEmpty)
        #expect(content.sound != nil)
    }
}

@MainActor
struct RenewalReminderTargetTests {
    private static let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
    private static let oneDay: TimeInterval = 60 * 60 * 24

    @Test("Earliest active subscription expiration wins when multiple entitlements present")
    func earliestExpirationSelected() {
        let monthly = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 20)
        )
        let annual = EntitlementSnapshot(
            productID: ProductIDs.proAnnual,
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 300)
        )
        let statuses = [
            SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .subscribed),
            SubscriptionStatusSnapshot(productID: ProductIDs.proAnnual, state: .subscribed),
        ]
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [monthly, annual],
            statuses: statuses,
            now: Self.now
        )
        #expect(target?.productID == ProductIDs.proMonthly)
    }

    @Test("Revoked entitlement is excluded from reminder target candidates")
    func revokedEntitlementExcluded() {
        let revoked = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: Self.now.addingTimeInterval(-60),
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 30)
        )
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [revoked],
            statuses: [],
            now: Self.now
        )
        #expect(target == nil)
    }

    @Test("Expired entitlement (past expirationDate) is excluded from reminder target")
    func expiredEntitlementExcluded() {
        let expired = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(-Self.oneDay)
        )
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [expired],
            statuses: [],
            now: Self.now
        )
        #expect(target == nil)
    }

    @Test("Status .expired with future entitlement expiration is excluded")
    func entitlementWithoutActiveStatusExcluded() {
        let entitlement = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 30)
        )
        let status = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .expired)
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [entitlement],
            statuses: [status],
            now: Self.now
        )
        #expect(target == nil)
    }

    @Test("Empty entitlements yields nil target even when status reports billing retry")
    func emptyEntitlementsYieldsNil() {
        let status = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .inBillingRetryPeriod)
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [],
            statuses: [status],
            now: Self.now
        )
        #expect(target == nil)
    }

    @Test("Unknown product ID is excluded from reminder target")
    func unknownProductExcluded() {
        let snapshot = EntitlementSnapshot(
            productID: "app.pairshot.unknown",
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 30)
        )
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [snapshot],
            statuses: [],
            now: Self.now
        )
        #expect(target == nil)
    }

    @Test("Active monthly entitlement (no status feed) still produces target")
    func activeEntitlementWithoutStatusProducesTarget() {
        let monthly = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 14)
        )
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [monthly],
            statuses: [],
            now: Self.now
        )
        #expect(target?.productID == ProductIDs.proMonthly)
    }
}
