import Foundation
import Observation

@MainActor
@Observable
final class AdFreeStore {
    private(set) var isAdFree: Bool = false
    private(set) var expiresAt: Date?
    private(set) var remainingDays: Int?
    private(set) var couponCount: Int = 0
    private(set) var activeCoupons: [AdFreeCouponInfo] = []

    private let fetcher: AdFreeStatusFetcher
    private let deviceHashProvider: DeviceHashProvider

    init(fetcher: AdFreeStatusFetcher, deviceHashProvider: DeviceHashProvider) {
        self.fetcher = fetcher
        self.deviceHashProvider = deviceHashProvider
    }

    func refresh() async {
        let hash = deviceHashProvider.deviceHash()
        guard let result = await fetcher.fetch(deviceHash: hash) else { return }
        isAdFree = result.active
        expiresAt = result.expiresAt
        remainingDays = result.remainingDays
        couponCount = result.couponCount
        activeCoupons = result.activeCoupons
    }
}
