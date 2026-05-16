import Foundation
@testable import PairShot
import Testing

@MainActor
struct PromotionStoreTests {
    private static let frozenNow = Date(timeIntervalSinceReferenceDate: 700_000_000)

    @Test
    func `Initial state: nothing active when no snapshot exists`() {
        let defaults = Self.makeIsolatedDefaults()
        let store = PromotionStore(
            fetcher: StubFetcher(snapshot: nil),
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults,
        )

        #expect(store.proIsActive == false)
        #expect(store.adFreeIsActive == false)
        #expect(store.proExpiresAt == nil)
        #expect(store.adFreeExpiresAt == nil)
    }

    @Test
    func `Ad-free promotion only: refresh sets adFreeIsActive but not proIsActive`() async {
        let defaults = Self.makeIsolatedDefaults()
        let expiry = Self.frozenNow.addingTimeInterval(60 * 60 * 24 * 30)
        let snapshot = MembershipSnapshot(
            pro: .init(active: false, expiresAt: nil),
            adFree: .init(active: true, expiresAt: expiry),
        )
        let store = PromotionStore(
            fetcher: StubFetcher(snapshot: snapshot),
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults,
        )

        await store.refresh()

        #expect(store.proIsActive == false)
        #expect(store.adFreeIsActive == true)
        #expect(store.adFreeExpiresAt == expiry)
    }

    @Test
    func `Pro promotion: refresh sets proIsActive (and adFree mirror inactive)`() async {
        let defaults = Self.makeIsolatedDefaults()
        let expiry = Self.frozenNow.addingTimeInterval(60 * 60 * 24 * 365)
        let snapshot = MembershipSnapshot(
            pro: .init(active: true, expiresAt: expiry),
            adFree: .init(active: false, expiresAt: nil),
        )
        let store = PromotionStore(
            fetcher: StubFetcher(snapshot: snapshot),
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults,
        )

        await store.refresh()

        #expect(store.proIsActive == true)
        #expect(store.proExpiresAt == expiry)
        #expect(store.adFreeIsActive == false)
    }

    @Test
    func `Permanent promotion: nil expiresAt preserved`() async {
        let defaults = Self.makeIsolatedDefaults()
        let snapshot = MembershipSnapshot(
            pro: .init(active: true, expiresAt: nil),
            adFree: .init(active: false, expiresAt: nil),
        )
        let store = PromotionStore(
            fetcher: StubFetcher(snapshot: snapshot),
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults,
        )

        await store.refresh()

        #expect(store.proIsActive == true)
        #expect(store.proExpiresAt == nil)
    }

    @Test
    func `refresh keeps state when fetcher returns nil`() async {
        let defaults = Self.makeIsolatedDefaults()
        let store = PromotionStore(
            fetcher: StubFetcher(snapshot: nil),
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults,
        )

        await store.refresh()

        #expect(store.proIsActive == false)
        #expect(store.adFreeIsActive == false)
    }

    @Test
    func `Snapshot persistence: subsequent init restores prior state`() async {
        let defaults = Self.makeIsolatedDefaults()
        let expiry = Self.frozenNow.addingTimeInterval(60 * 60 * 24 * 7)
        let snapshot = MembershipSnapshot(
            pro: .init(active: false, expiresAt: nil),
            adFree: .init(active: true, expiresAt: expiry),
        )
        let firstStore = PromotionStore(
            fetcher: StubFetcher(snapshot: snapshot),
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults,
        )
        await firstStore.refresh()

        let secondStore = PromotionStore(
            fetcher: StubFetcher(snapshot: nil),
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults,
        )

        #expect(secondStore.adFreeIsActive == true)
        #expect(secondStore.adFreeExpiresAt == expiry)
    }

    private static func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "PromotionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct StubFetcher: PromotionFetching {
    let snapshot: MembershipSnapshot?

    func fetch(deviceHash _: String) async -> MembershipSnapshot? {
        snapshot
    }
}
