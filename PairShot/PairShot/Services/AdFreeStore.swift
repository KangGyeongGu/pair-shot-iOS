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

    /// All currently-active coupons (status == `.active` and not yet
    /// past `expirationDate`), ordered by `expirationDate` descending —
    /// so the row with the most remaining time appears first in the
    /// settings list (P8.5).
    ///
    /// Computed on read: cardinality is small (≤ a handful) and we want
    /// the value to reflect any ad-hoc inserts since the last
    /// `refresh()` call without forcing the UI to call refresh again.
    var activeCoupons: [Coupon] {
        AdFreeCouponSorter.active(fetchAllCoupons(), now: .now)
    }

    /// All non-active coupons (expired or revoked), or coupons whose
    /// status is still `.active` but whose `expirationDate` has already
    /// elapsed. Ordered by `activatedAt` descending so the most recent
    /// past coupon shows first.
    var pastCoupons: [Coupon] {
        AdFreeCouponSorter.past(fetchAllCoupons(), now: .now)
    }

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
        fetchAllCoupons().filter { $0.status == .active }
    }

    private func fetchAllCoupons() -> [Coupon] {
        // Fetching all coupons and filtering in-memory keeps the predicate
        // off the `Coupon.status` enum (SwiftData `#Predicate` doesn't
        // support arbitrary `RawRepresentable` enum comparisons reliably
        // across iOS 17/18). Cardinality is tiny — at most a handful.
        let descriptor = FetchDescriptor<Coupon>()
        return (try? context.fetch(descriptor)) ?? []
    }
}

/// Pure helpers for splitting a flat list of `Coupon`s into the active /
/// past partitions surfaced by ``AdFreeStatusView`` (P8.5). Extracted so
/// the partitioning logic is unit-testable without spinning up a
/// ModelContainer.
///
/// "Active" mirrors `Coupon.isCurrentlyActive(now:)`: status must be
/// `.active` *and* the expiration must still be in the future. Anything
/// that fails either condition lands in "past" — including coupons whose
/// status is still nominally `.active` but whose expiration has elapsed
/// (`AdFreeStore.refresh()` will eventually flip them, but the settings
/// view shouldn't lie if the user opens it before refresh runs).
enum AdFreeCouponSorter {
    /// `status == .active && expirationDate >= now`, sorted by
    /// `expirationDate` descending so the longest-remaining coupon
    /// surfaces first.
    static func active(_ all: [Coupon], now: Date) -> [Coupon] {
        all
            .filter { $0.status == .active && $0.expirationDate > now }
            .sorted { $0.expirationDate > $1.expirationDate }
    }

    /// Inverse partition: anything not currently active. Sorted by
    /// `activatedAt` descending so the most recent past coupon is on top.
    static func past(_ all: [Coupon], now: Date) -> [Coupon] {
        all
            .filter { coupon in
                coupon.status != .active || coupon.expirationDate <= now
            }
            .sorted { $0.activatedAt > $1.activatedAt }
    }
}
