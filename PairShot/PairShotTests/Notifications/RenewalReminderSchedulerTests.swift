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

    @Test
    func `Expiration 8 days from now yields trigger date 1 day from now`() {
        let expiration = Self.now.addingTimeInterval(Self.oneDay * 8)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: Self.now,
            calendar: Self.calendar,
        )
        let unwrapped = try? #require(result)
        let delta = unwrapped?.timeIntervalSince(Self.now) ?? 0
        #expect(abs(delta - Self.oneDay) < 60)
    }

    @Test
    func `Expiration exactly 7 days from now yields nil (trigger == now, not strictly after)`() {
        let expiration = Self.now.addingTimeInterval(Self.oneDay * 7)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: Self.now,
            calendar: Self.calendar,
        )
        #expect(result == nil)
    }

    @Test
    func `Expiration 6 days from now yields nil (lead window already passed)`() {
        let expiration = Self.now.addingTimeInterval(Self.oneDay * 6)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: Self.now,
            calendar: Self.calendar,
        )
        #expect(result == nil)
    }

    @Test
    func `Past expiration date yields nil`() {
        let expiration = Self.now.addingTimeInterval(-Self.oneDay)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: Self.now,
            calendar: Self.calendar,
        )
        #expect(result == nil)
    }

    @Test
    func `Far-future expiration (annual subscription) yields trigger 358 days from now`() {
        let expiration = Self.now.addingTimeInterval(Self.oneDay * 365)
        let result = RenewalReminderScheduler.reminderTriggerDate(
            expirationDate: expiration,
            leadDays: 7,
            now: Self.now,
            calendar: Self.calendar,
        )
        let unwrapped = try? #require(result)
        let delta = unwrapped?.timeIntervalSince(Self.now) ?? 0
        #expect(abs(delta - Self.oneDay * 358) < 60)
    }

    @Test
    func `DST boundary: spring-forward calendar still produces 7-day-before trigger`() {
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
            calendar: calendar,
        )
        let unwrapped = try? #require(result)
        let delta = unwrapped?.timeIntervalSince(now) ?? 0
        #expect(delta > Self.oneDay * 0.9)
        #expect(delta < Self.oneDay * 1.1)
    }

    @Test
    func `Identifier prefix uses fixed namespace + product ID`() {
        let identifier = RenewalReminderScheduler.identifier(for: ProductIDs.proMonthly)
        #expect(identifier == "renewal_reminder_\(ProductIDs.proMonthly)")
        #expect(identifier.hasPrefix(RenewalReminderScheduler.identifierPrefix))
    }

    @Test
    func `makeContent populates title, body, and default sound`() {
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

    @Test
    func `Earliest active subscription expiration wins when multiple entitlements present`() {
        let monthly = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 20),
        )
        let annual = EntitlementSnapshot(
            productID: ProductIDs.proAnnual,
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 300),
        )
        let statuses = [
            SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .subscribed),
            SubscriptionStatusSnapshot(productID: ProductIDs.proAnnual, state: .subscribed),
        ]
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [monthly, annual],
            statuses: statuses,
            now: Self.now,
        )
        #expect(target?.productID == ProductIDs.proMonthly)
    }

    @Test
    func `Revoked entitlement is excluded from reminder target candidates`() {
        let revoked = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: Self.now.addingTimeInterval(-60),
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 30),
        )
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [revoked],
            statuses: [],
            now: Self.now,
        )
        #expect(target == nil)
    }

    @Test
    func `Expired entitlement (past expirationDate) is excluded from reminder target`() {
        let expired = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(-Self.oneDay),
        )
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [expired],
            statuses: [],
            now: Self.now,
        )
        #expect(target == nil)
    }

    @Test
    func `Status .expired with future entitlement expiration is excluded`() {
        let entitlement = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 30),
        )
        let status = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .expired)
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [entitlement],
            statuses: [status],
            now: Self.now,
        )
        #expect(target == nil)
    }

    @Test
    func `Empty entitlements yields nil target even when status reports billing retry`() {
        let status = SubscriptionStatusSnapshot(productID: ProductIDs.proMonthly, state: .inBillingRetryPeriod)
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [],
            statuses: [status],
            now: Self.now,
        )
        #expect(target == nil)
    }

    @Test
    func `Unknown product ID is excluded from reminder target`() {
        let snapshot = EntitlementSnapshot(
            productID: "app.pairshot.unknown",
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 30),
        )
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [snapshot],
            statuses: [],
            now: Self.now,
        )
        #expect(target == nil)
    }

    @Test
    func `Active monthly entitlement (no status feed) still produces target`() {
        let monthly = EntitlementSnapshot(
            productID: ProductIDs.proMonthly,
            revocationDate: nil,
            expirationDate: Self.now.addingTimeInterval(Self.oneDay * 14),
        )
        let target = SubscriptionStore.renewalReminderTarget(
            entitlements: [monthly],
            statuses: [],
            now: Self.now,
        )
        #expect(target?.productID == ProductIDs.proMonthly)
    }
}
