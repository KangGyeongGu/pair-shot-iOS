import Foundation
@testable import PairShot
import Testing

@MainActor
struct AdFreeStoreTests {
    private static let frozenNow = Date(timeIntervalSinceReferenceDate: 700_000_000)

    @Test("Initial state: isAdFree is false when no snapshot exists")
    func initialStateIsInactive() {
        let defaults = Self.makeIsolatedDefaults()
        let store = AdFreeStore(
            fetcher: StubFetcher(result: nil),
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults
        )

        #expect(store.isAdFree == false)
        #expect(store.expiresAt == nil)
        #expect(store.remainingDays == nil)
        #expect(store.couponCount == 0)
    }

    @Test("Coupon redemption: refresh sets isAdFree, couponCount, remainingDays")
    func refreshAppliesActiveResult() async {
        let defaults = Self.makeIsolatedDefaults()
        let expiry = Self.frozenNow.addingTimeInterval(60 * 60 * 24 * 30)
        let fetcher = StubFetcher(
            result: AdFreeStatusResult(
                active: true,
                expiresAt: expiry,
                remainingDays: 30,
                couponCount: 1
            )
        )
        let store = AdFreeStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults
        )

        await store.refresh()

        #expect(store.isAdFree == true)
        #expect(store.expiresAt == expiry)
        #expect(store.remainingDays == 30)
        #expect(store.couponCount == 1)
    }

    @Test("Expired coupon: fetcher returns active=false → isAdFree false")
    func expiredCouponRendersInactive() async {
        let defaults = Self.makeIsolatedDefaults()
        let fetcher = StubFetcher(
            result: AdFreeStatusResult(
                active: false,
                expiresAt: Self.frozenNow.addingTimeInterval(-60),
                remainingDays: 0,
                couponCount: 1
            )
        )
        let store = AdFreeStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults
        )

        await store.refresh()

        #expect(store.isAdFree == false)
        #expect(store.remainingDays == 0)
    }

    @Test("Permanent coupon: remainingDays nil, isAdFree true")
    func permanentCouponHasNilRemainingDays() async {
        let defaults = Self.makeIsolatedDefaults()
        let fetcher = StubFetcher(
            result: AdFreeStatusResult(
                active: true,
                expiresAt: nil,
                remainingDays: nil,
                couponCount: 1
            )
        )
        let store = AdFreeStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults
        )

        await store.refresh()

        #expect(store.isAdFree == true)
        #expect(store.expiresAt == nil)
        #expect(store.remainingDays == nil)
        #expect(store.couponCount == 1)
    }

    @Test("Multiple coupon stack: couponCount reflects accumulated total")
    func multipleCouponsAccumulate() async {
        let defaults = Self.makeIsolatedDefaults()
        let expiry = Self.frozenNow.addingTimeInterval(60 * 60 * 24 * 90)
        let fetcher = StubFetcher(
            result: AdFreeStatusResult(
                active: true,
                expiresAt: expiry,
                remainingDays: 90,
                couponCount: 3
            )
        )
        let store = AdFreeStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults
        )

        await store.refresh()

        #expect(store.isAdFree == true)
        #expect(store.couponCount == 3)
        #expect(store.remainingDays == 90)
    }

    @Test("refresh keeps state when fetcher returns nil")
    func refreshIsNoOpWhenFetcherReturnsNil() async {
        let defaults = Self.makeIsolatedDefaults()
        let fetcher = StubFetcher(result: nil)
        let store = AdFreeStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults
        )

        await store.refresh()

        #expect(store.isAdFree == false)
        #expect(store.couponCount == 0)
        #expect(store.remainingDays == nil)
        #expect(store.expiresAt == nil)
    }

    @Test("Snapshot persistence: subsequent init restores prior state")
    func snapshotIsPersistedAcrossInstances() async {
        let defaults = Self.makeIsolatedDefaults()
        let expiry = Self.frozenNow.addingTimeInterval(60 * 60 * 24 * 7)
        let fetcher = StubFetcher(
            result: AdFreeStatusResult(
                active: true,
                expiresAt: expiry,
                remainingDays: 7,
                couponCount: 2
            )
        )
        let firstStore = AdFreeStore(
            fetcher: fetcher,
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults
        )
        await firstStore.refresh()

        let secondStore = AdFreeStore(
            fetcher: StubFetcher(result: nil),
            deviceHashProvider: DeviceHashProvider(identifierResolver: { "device-id" }),
            defaults: defaults
        )

        #expect(secondStore.isAdFree == true)
        #expect(secondStore.couponCount == 2)
        #expect(secondStore.remainingDays == 7)
        #expect(secondStore.expiresAt == expiry)
    }

    private static func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "AdFreeStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct StubFetcher: AdFreeStatusFetching {
    let result: AdFreeStatusResult?

    func fetch(deviceHash _: String) async -> AdFreeStatusResult? {
        result
    }
}
