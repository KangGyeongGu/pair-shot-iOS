import Foundation
import Observation
import OSLog
import StoreKit

struct EntitlementSnapshot {
    let productID: String
    let revocationDate: Date?
    let expirationDate: Date?
}

struct SubscriptionStatusSnapshot {
    let productID: String
    let state: Product.SubscriptionInfo.RenewalState
}

struct RenewalReminderTarget: Equatable {
    let productID: String
    let expirationDate: Date
}

@MainActor
@Observable
final class SubscriptionStore {
    private(set) var isPro: Bool = false

    private(set) var proExpiresAt: Date?

    @ObservationIgnored private let renewalReminderScheduler: RenewalReminderScheduler?

    init(renewalReminderScheduler: RenewalReminderScheduler? = nil) {
        self.renewalReminderScheduler = renewalReminderScheduler
    }

    func refresh() async {
        let now = Date.now
        var entitlements: [EntitlementSnapshot] = []
        var unverifiedEntitlementCount = 0
        for await result in Transaction.currentEntitlements {
            switch result {
                case let .verified(transaction):
                    entitlements.append(EntitlementSnapshot(
                        productID: transaction.productID,
                        revocationDate: transaction.revocationDate,
                        expirationDate: transaction.expirationDate,
                    ))

                case let .unverified(_, error):
                    unverifiedEntitlementCount += 1
                    AppLogger.subscription
                        .error("Entitlement verification failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        if unverifiedEntitlementCount > 0 {
            AppLogger.subscription
                .error("Unverified entitlements dropped count=\(unverifiedEntitlementCount, privacy: .public)")
        }

        let statuses = await Self.fetchStatuses(productIDs: ProductIDs.allLoadable)
        isPro = Self.computeIsPro(entitlements: entitlements, statuses: statuses, now: now)
        proExpiresAt = Self.computeProExpiresAt(entitlements: entitlements, now: now)

        await syncRenewalReminder(
            target: Self.renewalReminderTarget(
                entitlements: entitlements,
                statuses: statuses,
                now: now,
            ),
        )
    }

    private func syncRenewalReminder(target: RenewalReminderTarget?) async {
        guard let renewalReminderScheduler else { return }
        guard let target else {
            await renewalReminderScheduler.cancelAll()
            return
        }
        await renewalReminderScheduler.schedule(
            productID: target.productID,
            expirationDate: target.expirationDate,
            productDisplayName: String(localized: "paywall_title"),
        )
    }

    nonisolated static func computeIsPro(
        entitlements: [EntitlementSnapshot],
        statuses: [SubscriptionStatusSnapshot],
        now: Date,
    ) -> Bool {
        for entitlement in entitlements where isActivePro(snapshot: entitlement, now: now) {
            return true
        }
        for status in statuses where isActiveProStatus(status) {
            return true
        }
        return false
    }

    nonisolated static func isActivePro(snapshot: EntitlementSnapshot, now: Date) -> Bool {
        guard ProductIDs.allProSet.contains(snapshot.productID) else { return false }
        guard snapshot.revocationDate == nil else { return false }
        let expiration = snapshot.expirationDate ?? .distantFuture
        return expiration > now
    }

    nonisolated static func computeProExpiresAt(
        entitlements: [EntitlementSnapshot],
        now: Date,
    ) -> Date? {
        let activeExpirations = entitlements.compactMap { entitlement -> Date? in
            guard isActivePro(snapshot: entitlement, now: now) else { return nil }
            return entitlement.expirationDate ?? .distantFuture
        }
        return activeExpirations.max()
    }

    nonisolated static func isActiveProStatus(_ status: SubscriptionStatusSnapshot) -> Bool {
        guard ProductIDs.allProSet.contains(status.productID) else { return false }
        switch status.state {
            case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                return true

            default:
                return false
        }
    }

    nonisolated static func renewalReminderTarget(
        entitlements: [EntitlementSnapshot],
        statuses: [SubscriptionStatusSnapshot],
        now: Date,
    ) -> RenewalReminderTarget? {
        let activeStatusProducts = Set(
            statuses
                .filter(isActiveProStatus)
                .map(\.productID),
        )
        let knownStatusProducts = Set(statuses.map(\.productID))
        let candidates: [(String, Date)] = entitlements.compactMap { snapshot in
            guard ProductIDs.allProSet.contains(snapshot.productID) else { return nil }
            guard snapshot.revocationDate == nil else { return nil }
            guard let expiration = snapshot.expirationDate, expiration > now else { return nil }
            if knownStatusProducts.contains(snapshot.productID),
               !activeStatusProducts.contains(snapshot.productID)
            {
                return nil
            }
            return (snapshot.productID, expiration)
        }
        guard let earliest = candidates.min(by: { $0.1 < $1.1 }) else { return nil }
        return RenewalReminderTarget(productID: earliest.0, expirationDate: earliest.1)
    }

    private static func fetchStatuses(productIDs: [String]) async -> [SubscriptionStatusSnapshot] {
        var snapshots: [SubscriptionStatusSnapshot] = []
        let products: [Product]
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            AppLogger.subscription
                .error("Product.products failed: \(error.localizedDescription, privacy: .public)")
            return snapshots
        }
        for product in products {
            guard let subscription = product.subscription else { continue }
            let statuses: [Product.SubscriptionInfo.Status]
            do {
                statuses = try await subscription.status
            } catch {
                AppLogger.subscription
                    .error(
                        "SubscriptionInfo.status failed product=\(product.id, privacy: .public) error=\(error.localizedDescription, privacy: .public)",
                    )
                continue
            }
            for status in statuses {
                snapshots.append(SubscriptionStatusSnapshot(
                    productID: product.id,
                    state: status.state,
                ))
            }
        }
        return snapshots
    }
}
