import Foundation
import Observation

@MainActor
@Observable
final class AdFreeStore {
    private(set) var isAdFree: Bool
    private(set) var expiresAt: Date?
    private(set) var remainingDays: Int?
    private(set) var couponCount: Int
    private(set) var activeCoupons: [AdFreeCouponInfo]

    private let fetcher: AdFreeStatusFetcher
    private let deviceHashProvider: DeviceHashProvider
    private let defaults: UserDefaults

    init(
        fetcher: AdFreeStatusFetcher,
        deviceHashProvider: DeviceHashProvider,
        defaults: UserDefaults = .standard
    ) {
        self.fetcher = fetcher
        self.deviceHashProvider = deviceHashProvider
        self.defaults = defaults
        let snapshot = Self.loadSnapshot(from: defaults)
        isAdFree = snapshot?.active ?? false
        expiresAt = snapshot?.expiresAt
        remainingDays = snapshot?.remainingDays
        couponCount = snapshot?.couponCount ?? 0
        activeCoupons = snapshot?.activeCoupons ?? []
    }

    func refresh() async {
        let hash = deviceHashProvider.deviceHash()
        guard let result = await fetcher.fetch(deviceHash: hash) else { return }
        isAdFree = result.active
        expiresAt = result.expiresAt
        remainingDays = result.remainingDays
        couponCount = result.couponCount
        activeCoupons = result.activeCoupons
        Self.saveSnapshot(result, to: defaults)
    }

    private static let snapshotKey = "pairshot.adFreeStore.snapshot"

    private static func loadSnapshot(from defaults: UserDefaults) -> AdFreeStatusResult? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AdFreeStatusResult.self, from: data)
    }

    private static func saveSnapshot(_ result: AdFreeStatusResult, to defaults: UserDefaults) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(result) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}
