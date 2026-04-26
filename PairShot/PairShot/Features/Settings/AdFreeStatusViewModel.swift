import Foundation
import Observation

@MainActor
@Observable
final class AdFreeStatusViewModel {
    let store: AdFreeStore

    var isAdFree: Bool {
        store.isAdFree
    }

    var activeCoupons: [Coupon] {
        store.activeCoupons
    }

    var pastCoupons: [Coupon] {
        store.pastCoupons
    }

    init(store: AdFreeStore) {
        self.store = store
    }

    func headline(now: Date = .now) -> String {
        AdFreeStatusFormatter.headline(
            isAdFree: store.isAdFree,
            latestExpiration: store.currentExpiration,
            now: now
        )
    }

    func pastStatusLabel(for coupon: Coupon) -> String {
        AdFreeStatusFormatter.pastStatusLabel(for: coupon)
    }

    func maskedCode(for coupon: Coupon) -> String {
        AdFreeStatusFormatter.maskCode(coupon.code)
    }

    func formattedDate(_ date: Date) -> String {
        AdFreeStatusFormatter.formatDate(date)
    }

    func refresh(now: Date = .now) {
        store.refresh(now: now)
    }

    deinit {}
}
