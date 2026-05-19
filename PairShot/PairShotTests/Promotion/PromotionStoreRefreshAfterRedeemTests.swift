import Foundation
@testable import PairShot
import Testing

@MainActor
struct PromotionStoreRefreshAfterRedeemTests {
    private static let frozenNow = Date(timeIntervalSinceReferenceDate: 700_000_000)

    @Test
    func `proIsActive 가 첫 refresh 후 true 면 retry skip (fetch 1회만)`() async {
        let defaults = Self.makeIsolatedDefaults()
        let expiry = Self.frozenNow.addingTimeInterval(60 * 60 * 24 * 30)
        let snapshot = MembershipSnapshot(
            pro: .init(active: true, expiresAt: expiry),
            adFree: .init(active: false, expiresAt: nil),
        )
        let fetcher = CountingFetcher(snapshots: [snapshot])
        let store = PromotionStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device" }),
            defaults: defaults,
            clock: { Self.frozenNow },
        )

        await store.refreshAfterRedeem(retryDelay: .zero)

        #expect(await fetcher.callCount == 1)
        #expect(store.proIsActive)
    }

    @Test
    func `adFreeIsActive 가 첫 refresh 후 true 면 retry skip (fetch 1회만)`() async {
        let defaults = Self.makeIsolatedDefaults()
        let expiry = Self.frozenNow.addingTimeInterval(60 * 60 * 24 * 30)
        let snapshot = MembershipSnapshot(
            pro: .init(active: false, expiresAt: nil),
            adFree: .init(active: true, expiresAt: expiry),
        )
        let fetcher = CountingFetcher(snapshots: [snapshot])
        let store = PromotionStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device" }),
            defaults: defaults,
            clock: { Self.frozenNow },
        )

        await store.refreshAfterRedeem(retryDelay: .zero)

        #expect(await fetcher.callCount == 1)
        #expect(store.adFreeIsActive)
    }

    @Test
    func `둘 다 inactive 면 retry — fetch 가 정확히 2회 호출`() async {
        let defaults = Self.makeIsolatedDefaults()
        let inactiveSnapshot = MembershipSnapshot(
            pro: .init(active: false, expiresAt: nil),
            adFree: .init(active: false, expiresAt: nil),
        )
        let fetcher = CountingFetcher(snapshots: [inactiveSnapshot, inactiveSnapshot])
        let store = PromotionStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device" }),
            defaults: defaults,
            clock: { Self.frozenNow },
        )

        await store.refreshAfterRedeem(retryDelay: .zero)

        #expect(await fetcher.callCount == 2)
        #expect(!store.proIsActive)
        #expect(!store.adFreeIsActive)
    }

    @Test
    func `둘 다 inactive 후 2차 retry 에서 active 가 되면 상태 갱신`() async {
        let defaults = Self.makeIsolatedDefaults()
        let inactiveSnapshot = MembershipSnapshot(
            pro: .init(active: false, expiresAt: nil),
            adFree: .init(active: false, expiresAt: nil),
        )
        let expiry = Self.frozenNow.addingTimeInterval(3600)
        let activeSnapshot = MembershipSnapshot(
            pro: .init(active: true, expiresAt: expiry),
            adFree: .init(active: false, expiresAt: nil),
        )
        let fetcher = CountingFetcher(snapshots: [inactiveSnapshot, activeSnapshot])
        let store = PromotionStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device" }),
            defaults: defaults,
            clock: { Self.frozenNow },
        )

        await store.refreshAfterRedeem(retryDelay: .zero)

        #expect(await fetcher.callCount == 2)
        #expect(store.proIsActive)
        #expect(store.proExpiresAt == expiry)
    }

    @Test
    func `2회 모두 inactive 면 retry 후에도 상태 유지 — 추가 호출 없음`() async {
        let defaults = Self.makeIsolatedDefaults()
        let inactiveSnapshot = MembershipSnapshot(
            pro: .init(active: false, expiresAt: nil),
            adFree: .init(active: false, expiresAt: nil),
        )
        let fetcher = CountingFetcher(snapshots: [inactiveSnapshot, inactiveSnapshot, inactiveSnapshot])
        let store = PromotionStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device" }),
            defaults: defaults,
            clock: { Self.frozenNow },
        )

        await store.refreshAfterRedeem(retryDelay: .zero)

        #expect(await fetcher.callCount == 2)
    }

    @Test
    func `nil snapshot 응답 후에도 retry 진행 — fetch 2회 호출`() async {
        let defaults = Self.makeIsolatedDefaults()
        let fetcher = CountingFetcher(snapshots: [nil, nil])
        let store = PromotionStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device" }),
            defaults: defaults,
            clock: { Self.frozenNow },
        )

        await store.refreshAfterRedeem(retryDelay: .zero)

        #expect(await fetcher.callCount == 2)
        #expect(!store.proIsActive)
        #expect(!store.adFreeIsActive)
    }

    @Test
    func `retryDelay 가 zero 가 아닐 때도 호출 횟수는 동일 — 동작 invariant`() async {
        let defaults = Self.makeIsolatedDefaults()
        let inactiveSnapshot = MembershipSnapshot(
            pro: .init(active: false, expiresAt: nil),
            adFree: .init(active: false, expiresAt: nil),
        )
        let fetcher = CountingFetcher(snapshots: [inactiveSnapshot, inactiveSnapshot])
        let store = PromotionStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device" }),
            defaults: defaults,
            clock: { Self.frozenNow },
        )

        await store.refreshAfterRedeem(retryDelay: .milliseconds(10))

        #expect(await fetcher.callCount == 2)
    }

    private static func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "PromotionStoreRefreshAfterRedeemTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private actor CountingFetcher: PromotionFetching {
    private var snapshots: [MembershipSnapshot?]
    private(set) var callCount = 0

    init(snapshots: [MembershipSnapshot?]) {
        self.snapshots = snapshots
    }

    func fetch(deviceHash _: String) async -> MembershipSnapshot? {
        callCount += 1
        guard !snapshots.isEmpty else { return nil }
        return snapshots.removeFirst()
    }
}
