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
        let allEntities = fetchAllEntities()
        let activeOnDisk = allEntities.filter { $0.status == .active }
        var stillActiveDomain: [Coupon] = []
        for entity in activeOnDisk {
            let domain = Self.toDomain(entity)
            if domain.isCurrentlyActive(now: now) {
                stillActiveDomain.append(domain)
            } else {
                entity.status = .expired
            }
        }
        do {
            try context.save()
        } catch {
            AppLogger.coupon.error(
                "AdFreeStore context save failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        let refreshedAll = fetchAllEntities().map(Self.toDomain)
        activeCoupons = AdFreeCouponSorter.active(refreshedAll, now: now)
        pastCoupons = AdFreeCouponSorter.past(refreshedAll, now: now)

        if let latest = stillActiveDomain.map(\.expirationDate).max() {
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
        let activeOnDisk = fetchAllEntities().filter { $0.status == .active }
        guard !activeOnDisk.isEmpty else { return }
        let hash = deviceHashProvider.deviceHash()
        var changed = false
        for entity in activeOnDisk where !entity.serverCouponId.isEmpty {
            let request = StatusRequestDto(couponId: entity.serverCouponId, deviceHash: hash)
            let result = await api.fetchStatus(request)
            switch result {
                case .activated:
                    break

                case .revoked, .notFoundOrForeign:
                    entity.status = .revoked
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

    private func fetchAllEntities() -> [CouponEntity] {
        let descriptor = FetchDescriptor<CouponEntity>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func toDomain(_ entity: CouponEntity) -> Coupon {
        Coupon(
            id: entity.id,
            code: entity.code,
            activatedAt: entity.activatedAt,
            durationDays: entity.durationDays,
            signatureBase64: entity.signatureBase64,
            status: entity.status,
            kindRawString: entity.kindRawString,
            payloadVersion: entity.payloadVersion,
            issuedAt: entity.issuedAt,
            serverCouponId: entity.serverCouponId
        )
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
