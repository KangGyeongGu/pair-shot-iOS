import Foundation
import Observation

@MainActor
@Observable
final class PromotionStore {
    private static let snapshotKey = "pairshot.promotionStore.snapshot"

    private(set) var proIsActive: Bool
    private(set) var proExpiresAt: Date?
    private(set) var adFreeIsActive: Bool
    private(set) var adFreeExpiresAt: Date?

    private let fetcher: any PromotionFetching
    private let deviceHashProvider: DeviceHashProvider
    private let defaults: UserDefaults

    init(
        fetcher: any PromotionFetching,
        deviceHashProvider: DeviceHashProvider,
        defaults: UserDefaults = .standard,
    ) {
        self.fetcher = fetcher
        self.deviceHashProvider = deviceHashProvider
        self.defaults = defaults
        let snapshot = Self.loadSnapshot(from: defaults) ?? .empty
        proIsActive = snapshot.pro.active
        proExpiresAt = snapshot.pro.expiresAt
        adFreeIsActive = snapshot.adFree.active
        adFreeExpiresAt = snapshot.adFree.expiresAt
    }

    func refresh() async {
        let hash = deviceHashProvider.deviceHash()
        guard let snapshot = await fetcher.fetch(deviceHash: hash) else { return }
        proIsActive = snapshot.pro.active
        proExpiresAt = snapshot.pro.expiresAt
        adFreeIsActive = snapshot.adFree.active
        adFreeExpiresAt = snapshot.adFree.expiresAt
        Self.saveSnapshot(snapshot, to: defaults)
    }

    private static func loadSnapshot(from defaults: UserDefaults) -> MembershipSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MembershipSnapshot.self, from: data)
    }

    private static func saveSnapshot(_ snapshot: MembershipSnapshot, to defaults: UserDefaults) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}
