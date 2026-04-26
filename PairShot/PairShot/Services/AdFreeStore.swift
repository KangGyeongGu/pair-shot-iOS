import Foundation
import Observation
import SwiftData

/// Tracks the current ad-free entitlement based on persisted `Coupon`
/// entities in SwiftData.
///
/// `isAdFree` is `true` when at least one `Coupon` is `.active` and its
/// computed `expirationDate` is in the future. The store does **not**
/// auto-refresh on a timer — callers should `refresh()` after redeeming
/// a coupon and on app foregrounding (where the date may have rolled
/// past an expiration). This avoids a hot loop and keeps publish
/// surface predictable.
///
/// Per CLAUDE.md core principle 7: ad call sites must check
/// `adFreeStore.isAdFree` before invoking the SDK.
@MainActor
@Observable
final class AdFreeStore {
    /// `true` when at least one currently-active coupon exists.
    private(set) var isAdFree: Bool = false

    /// The latest expiration date among currently-active coupons,
    /// `nil` when none are active. Useful for Settings UI (P8.5).
    private(set) var currentExpiration: Date?

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        refresh()
    }

    /// Re-fetches active coupons and updates `isAdFree` /
    /// `currentExpiration`. Also rolls expired-but-still-`.active`
    /// coupons over to `.expired` so the next refresh is fast.
    func refresh(now: Date = .now) {
        let activeCoupons = fetchActiveCoupons()
        var stillActive: [Coupon] = []
        for coupon in activeCoupons {
            if coupon.isCurrentlyActive(now: now) {
                stillActive.append(coupon)
            } else {
                coupon.status = .expired
            }
        }
        // Persist any rollover. Best-effort — failure shouldn't crash UI.
        try? context.save()

        if let latest = stillActive.map(\.expirationDate).max() {
            currentExpiration = latest
            isAdFree = true
        } else {
            currentExpiration = nil
            isAdFree = false
        }
    }

    private func fetchActiveCoupons() -> [Coupon] {
        // Fetching all coupons and filtering in-memory keeps the predicate
        // off the `Coupon.status` enum (SwiftData `#Predicate` doesn't
        // support arbitrary `RawRepresentable` enum comparisons reliably
        // across iOS 17/18). Cardinality is tiny — at most a handful.
        let descriptor = FetchDescriptor<Coupon>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.status == .active }
    }
}
