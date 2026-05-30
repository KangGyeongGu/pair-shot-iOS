import Foundation
@testable import PairShot
import Testing

@MainActor
struct ExportPresetStoreTests {
    private struct TestEnv {
        let defaults: UserDefaults
        let appSettings: AppSettings
        let preferences: ExportPreferences
        let store: ExportPresetStore
        let logoStore: WatermarkLogoStore
    }

    @Test
    func `초기 상태 — 모든 슬롯 비어있음, 활성 인덱스 0`() {
        let env = makeEnv()

        #expect(env.store.presets.count == 4)
        #expect(env.store.presets.allSatisfy { $0 == nil })
        #expect(env.store.activeIndex == 0)
        #expect(env.store.active == nil)
    }

    @Test
    func `seedDefaultIfNeeded — 1번이 비어있으면 현재 글로벌 값으로 채움, 활성 0`() {
        let env = makeEnv()
        env.appSettings.watermarkEnabled = true

        env.store.seedDefaultIfNeeded(name: "기본")

        #expect(env.store.presets[0]?.name == "기본")
        #expect(env.store.presets[0]?.applyWatermark == true)
        #expect(env.store.activeIndex == 0)
    }

    @Test
    func `seedDefaultIfNeeded — 1번이 이미 있으면 덮어쓰지 않음`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        let originalId = env.store.presets[0]?.id

        env.store.seedDefaultIfNeeded(name: "다른이름")

        #expect(env.store.presets[0]?.id == originalId)
        #expect(env.store.presets[0]?.name == "기본")
    }

    @Test
    func `save — 지정 슬롯에 현재 글로벌 스냅샷 저장 (활성 인덱스는 그대로)`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        env.preferences.includeBefore = true

        env.store.save(at: 1, name: "공유용")

        #expect(env.store.presets[1]?.name == "공유용")
        #expect(env.store.presets[1]?.includeBefore == true)
        #expect(env.store.activeIndex == 0)
    }

    @Test
    func `switchActive — 인덱스 변경 + 글로벌이 해당 프리셋 값으로 덮어써짐`() {
        let env = makeEnv()
        env.preferences.includeBefore = true
        env.preferences.includeAfter = false
        env.store.seedDefaultIfNeeded(name: "기본")
        env.preferences.includeBefore = false
        env.preferences.includeAfter = true
        env.store.save(at: 1, name: "After 만")

        env.store.switchActive(to: 0)

        #expect(env.store.activeIndex == 0)
        #expect(env.preferences.includeBefore == true)
        #expect(env.preferences.includeAfter == false)
    }

    @Test
    func `delete — 비활성 슬롯 제거, 활성 인덱스 변화 없음`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        env.store.save(at: 1, name: "B")
        env.store.save(at: 2, name: "C")

        env.store.delete(at: 2)

        #expect(env.store.presets[2] == nil)
        #expect(env.store.presets[1]?.name == "B")
        #expect(env.store.activeIndex == 0)
    }

    @Test
    func `delete — 활성 슬롯 제거 시 활성이 0번으로 fallback`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        env.store.save(at: 2, name: "C")
        env.store.switchActive(to: 2)

        env.store.delete(at: 2)

        #expect(env.store.presets[2] == nil)
        #expect(env.store.activeIndex == 0)
    }

    @Test
    func `delete — 중간 슬롯 제거 시 뒤 슬롯들이 좌측으로 당겨짐`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "A")
        env.store.save(at: 1, name: "B")
        env.store.save(at: 2, name: "C")
        env.store.save(at: 3, name: "D")

        env.store.delete(at: 1)

        #expect(env.store.presets[0]?.name == "A")
        #expect(env.store.presets[1]?.name == "C")
        #expect(env.store.presets[2]?.name == "D")
        #expect(env.store.presets[3] == nil)
    }

    @Test
    func `delete — 삭제 슬롯보다 뒤가 활성이면 activeIndex 1 감소`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "A")
        env.store.save(at: 1, name: "B")
        env.store.save(at: 2, name: "C")
        env.store.save(at: 3, name: "D")
        env.store.switchActive(to: 3)

        env.store.delete(at: 1)

        #expect(env.store.activeIndex == 2)
        #expect(env.store.presets[2]?.name == "D")
    }

    @Test
    func `delete — 0번 슬롯 삭제는 거부 (항상 유지)`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")

        env.store.delete(at: 0)

        #expect(env.store.presets[0] != nil)
    }

    @Test
    func `rename — 이름만 변경, 다른 값 보존`() {
        let env = makeEnv()
        env.preferences.includeBefore = true
        env.store.seedDefaultIfNeeded(name: "기본")
        let originalId = env.store.presets[0]?.id

        env.store.rename(at: 0, to: "내 기본")

        #expect(env.store.presets[0]?.name == "내 기본")
        #expect(env.store.presets[0]?.id == originalId)
        #expect(env.store.presets[0]?.includeBefore == true)
    }

    @Test
    func `syncFromGlobal — 활성 프리셋이 현재 글로벌 값과 일치하도록 갱신`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        env.preferences.includeBefore = true
        env.appSettings.watermarkEnabled = true

        env.store.syncFromGlobal()

        #expect(env.store.presets[0]?.includeBefore == true)
        #expect(env.store.presets[0]?.applyWatermark == true)
    }

    @Test
    func `syncFromGlobal — 활성 프리셋이 없으면 안전 no-op`() {
        let env = makeEnv()

        env.store.syncFromGlobal()

        #expect(env.store.active == nil)
    }

    @Test
    func `persist + reload — 저장된 프리셋이 다음 인스턴스에서 그대로 로드됨`() {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        env.store.save(at: 1, name: "B")
        env.store.switchActive(to: 1)

        let reloaded = ExportPresetStore(
            appSettings: env.appSettings,
            preferences: env.preferences,
            defaults: env.defaults,
        )

        #expect(reloaded.presets[0]?.name == "기본")
        #expect(reloaded.presets[1]?.name == "B")
        #expect(reloaded.activeIndex == 1)
    }

    @Test
    func `delete — 삭제된 슬롯에만 있던 logo ref 파일은 정리`() throws {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "A")
        let logoBytes = Data([0x11, 0x22])
        let ref = try env.logoStore.save(logoBytes)
        env.appSettings.watermarkSettings = WatermarkSettings(type: .logo, logoImageRef: ref)
        env.store.save(at: 1, name: "B")
        env.appSettings.watermarkSettings = WatermarkSettings(type: .text)

        env.store.delete(at: 1)

        #expect(env.logoStore.load(ref: ref) == nil)
    }

    @Test
    func `delete — 다른 슬롯이 동일 ref 사용 중이면 파일 보존`() throws {
        let env = makeEnv()
        let logoBytes = Data([0x33, 0x44])
        let ref = try env.logoStore.save(logoBytes)
        env.appSettings.watermarkSettings = WatermarkSettings(type: .logo, logoImageRef: ref)
        env.store.seedDefaultIfNeeded(name: "A")
        env.store.save(at: 1, name: "B")

        env.store.delete(at: 1)

        #expect(env.logoStore.load(ref: ref) == logoBytes)
    }

    @Test
    func `save replace — 옛 슬롯의 logo ref 파일이 다른 곳에서 미사용이면 정리`() throws {
        let env = makeEnv()
        env.store.seedDefaultIfNeeded(name: "기본")
        let oldBytes = Data([0x55, 0x66])
        let oldRef = try env.logoStore.save(oldBytes)
        env.appSettings.watermarkSettings = WatermarkSettings(type: .logo, logoImageRef: oldRef)
        env.store.save(at: 1, name: "B")
        env.appSettings.watermarkSettings = WatermarkSettings(type: .text)

        env.store.save(at: 1, name: "B-replaced")

        #expect(env.logoStore.load(ref: oldRef) == nil)
    }

    private func makeEnv() -> TestEnv {
        let suite = "preset-store-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let appSettings = AppSettings(defaults: defaults)
        let preferences = ExportPreferences(defaults: defaults)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportPresetStoreTest-\(UUID().uuidString)", isDirectory: true)
        let logoStore = WatermarkLogoStore(baseDirectory: tempDir)
        let store = ExportPresetStore(
            appSettings: appSettings,
            preferences: preferences,
            defaults: defaults,
            logoStore: logoStore,
        )
        return TestEnv(
            defaults: defaults,
            appSettings: appSettings,
            preferences: preferences,
            store: store,
            logoStore: logoStore,
        )
    }
}
