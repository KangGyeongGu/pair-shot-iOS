import Foundation
@testable import PairShot
import Testing

@MainActor
struct MembershipDowngradeReconcilerTests {
    private struct TestEnv {
        let preferences: ExportPreferences
        let store: ExportPresetStore
    }

    @Test
    func `isPro = true 면 no-op`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        env.store.save(at: 2, name: "C")
        env.store.switchActive(to: 2)
        env.preferences.format = .zip

        MembershipDowngradeReconciler.reconcile(
            isPro: true,
            presetStore: env.store,
            preferences: env.preferences,
        )

        #expect(env.store.activeIndex == 2)
        #expect(env.preferences.format == .zip)
    }

    @Test
    func `isPro = false 이고 active 가 잠금 슬롯이면 0 으로 fallback + globals 슬롯 0 값 복원`() {
        let env = makeEnv()
        env.preferences.includeBefore = true
        env.store.seedDefaultIfNeeded(name: "기본")
        env.preferences.includeBefore = false
        env.store.save(at: 2, name: "C")
        env.store.switchActive(to: 2)

        MembershipDowngradeReconciler.reconcile(
            isPro: false,
            presetStore: env.store,
            preferences: env.preferences,
        )

        #expect(env.store.activeIndex == 0)
        #expect(env.preferences.includeBefore == true)
        #expect(env.store.presets[2]?.name == "C")
    }

    @Test
    func `isPro = false 이고 active 가 허용 슬롯이면 activeIndex 유지`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        env.store.save(at: 1, name: "B")
        env.store.switchActive(to: 1)

        MembershipDowngradeReconciler.reconcile(
            isPro: false,
            presetStore: env.store,
            preferences: env.preferences,
        )

        #expect(env.store.activeIndex == 1)
    }

    @Test
    func `isPro = false 이고 format = zip 이면 individualImages 로 강등`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        env.preferences.format = .zip

        MembershipDowngradeReconciler.reconcile(
            isPro: false,
            presetStore: env.store,
            preferences: env.preferences,
        )

        #expect(env.preferences.format == .individualImages)
    }

    @Test
    func `isPro = false 이고 format = individualImages 면 그대로 유지`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        env.preferences.format = .individualImages

        MembershipDowngradeReconciler.reconcile(
            isPro: false,
            presetStore: env.store,
            preferences: env.preferences,
        )

        #expect(env.preferences.format == .individualImages)
    }

    private func makeEnv() -> TestEnv {
        let suite = "downgrade-reconciler-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let appSettings = AppSettings(defaults: defaults)
        let preferences = ExportPreferences(defaults: defaults)
        let store = ExportPresetStore(
            appSettings: appSettings,
            preferences: preferences,
            defaults: defaults,
        )
        return TestEnv(
            preferences: preferences,
            store: store,
        )
    }
}
