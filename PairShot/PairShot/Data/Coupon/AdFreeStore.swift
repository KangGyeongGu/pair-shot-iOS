import Foundation
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class AdFreeStore {
    private(set) var isAdFree: Bool = false
    private(set) var currentExpiration: Date?
    private(set) var activeCoupons: [Coupon] = []
    private(set) var pastCoupons: [Coupon] = []

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        refresh()
    }

    func refresh(now: Date = .now) {
        let allCoupons = fetchAllCoupons()
        let activeOnDisk = allCoupons.filter { $0.status == .active }
        var stillActive: [Coupon] = []
        for coupon in activeOnDisk {
            if coupon.isCurrentlyActive(now: now) {
                stillActive.append(coupon)
            } else {
                coupon.status = .expired
            }
        }
        do {
            try context.save()
        } catch {
            AppLogger.coupon.error(
                "AdFreeStore context save failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        let refreshedAll = fetchAllCoupons()
        activeCoupons = AdFreeCouponSorter.active(refreshedAll, now: now)
        pastCoupons = AdFreeCouponSorter.past(refreshedAll, now: now)

        if let latest = stillActive.map(\.expirationDate).max() {
            currentExpiration = latest
            isAdFree = true
        } else {
            currentExpiration = nil
            isAdFree = false
        }
        let snapshotAdFree = isAdFree
        let snapshotActiveCount = activeCoupons.count
        AppLogger.coupon.debug(
            "AdFreeStore refreshed isAdFree=\(snapshotAdFree, privacy: .public) active=\(snapshotActiveCount, privacy: .public)"
        )
    }

    func refreshFromServer(
        api: URLSessionCouponActivationApi,
        deviceHashProvider: DeviceHashProvider,
        now: Date = .now
    ) async {
        refresh(now: now)
        let activeOnDisk = fetchAllCoupons().filter { $0.status == .active }
        guard !activeOnDisk.isEmpty else { return }
        let hash = deviceHashProvider.deviceHash()
        var changed = false
        for coupon in activeOnDisk where !coupon.serverCouponId.isEmpty {
            let request = StatusRequestDto(couponId: coupon.serverCouponId, deviceHash: hash)
            let result = await api.fetchStatus(request)
            switch result {
                case .activated:
                    break

                case .revoked, .notFoundOrForeign:
                    coupon.status = .revoked
                    changed = true

                case .networkError, .serverError:
                    break
            }
        }
        if changed {
            do {
                try context.save()
            } catch {
                AppLogger.coupon.error(
                    "AdFreeStore server sync save failed: \(error.localizedDescription, privacy: .public)"
                )
            }
            refresh(now: now)
        }
    }

    private func fetchAllCoupons() -> [Coupon] {
        let descriptor = FetchDescriptor<Coupon>()
        return (try? context.fetch(descriptor)) ?? []
    }
}

enum AdFreeCouponSorter {
    static func active(_ all: [Coupon], now: Date) -> [Coupon] {
        all
            .filter { $0.status == .active && $0.expirationDate > now }
            .sorted { $0.expirationDate > $1.expirationDate }
    }

    static func past(_ all: [Coupon], now: Date) -> [Coupon] {
        all
            .filter { coupon in
                coupon.status != .active || coupon.expirationDate <= now
            }
            .sorted { $0.activatedAt > $1.activatedAt }
    }
}
