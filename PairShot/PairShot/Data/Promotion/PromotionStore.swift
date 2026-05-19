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
    private let clock: @MainActor @Sendable () -> Date

    init(
        fetcher: any PromotionFetching,
        deviceHashProvider: DeviceHashProvider,
        defaults: UserDefaults = .standard,
        clock: @escaping @MainActor @Sendable () -> Date = { Date() },
    ) {
        self.fetcher = fetcher
        self.deviceHashProvider = deviceHashProvider
        self.defaults = defaults
        self.clock = clock
        let snapshot = Self.loadSnapshot(from: defaults) ?? .empty
        let now = clock()
        proIsActive = Self.resolveActive(state: snapshot.pro, now: now)
        proExpiresAt = snapshot.pro.expiresAt
        adFreeIsActive = Self.resolveActive(state: snapshot.adFree, now: now)
        adFreeExpiresAt = snapshot.adFree.expiresAt
    }

    func refresh() async {
        let hash = deviceHashProvider.deviceHash()
        guard let snapshot = await fetcher.fetch(deviceHash: hash) else { return }
        let now = clock()
        proIsActive = Self.resolveActive(state: snapshot.pro, now: now)
        proExpiresAt = snapshot.pro.expiresAt
        adFreeIsActive = Self.resolveActive(state: snapshot.adFree, now: now)
        adFreeExpiresAt = snapshot.adFree.expiresAt
        Self.saveSnapshot(snapshot, to: defaults)
    }

    func refreshAfterRedeem(retryDelay: Duration = .seconds(2)) async {
        await refresh()
        if proIsActive || adFreeIsActive { return }
        try? await Task.sleep(for: retryDelay)
        await refresh()
    }

    private static func resolveActive(
        state: MembershipSnapshot.EntitlementState,
        now: Date,
    ) -> Bool {
        guard state.active else { return false }
        guard let expiresAt = state.expiresAt else { return true }
        return expiresAt > now
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
