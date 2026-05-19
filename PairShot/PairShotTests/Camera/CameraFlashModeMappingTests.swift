@testable import PairShot
import Testing

struct CameraFlashModeMappingTests {
    @Test
    func `flashMode from raw — ON 문자열 → on`() {
        #expect(CameraFlashModeMapping.flashMode(from: CameraFlashModePersistence.on) == .on)
    }

    @Test
    func `flashMode from raw — AUTO 문자열 → auto`() {
        #expect(CameraFlashModeMapping.flashMode(from: CameraFlashModePersistence.auto) == .auto)
    }

    @Test
    func `flashMode from raw — TORCH 문자열 → torch`() {
        #expect(CameraFlashModeMapping.flashMode(from: CameraFlashModePersistence.torch) == .torch)
    }

    @Test
    func `flashMode from raw — OFF 문자열 → off`() {
        #expect(CameraFlashModeMapping.flashMode(from: CameraFlashModePersistence.off) == .off)
    }

    @Test
    func `flashMode from raw — 알 수 없는 문자열은 off 로 기본값 처리`() {
        #expect(CameraFlashModeMapping.flashMode(from: "UNKNOWN") == .off)
        #expect(CameraFlashModeMapping.flashMode(from: "") == .off)
        #expect(CameraFlashModeMapping.flashMode(from: "on") == .on)
    }

    @Test
    func `persisted from enum — 모든 케이스가 정공 문자열 반환`() {
        #expect(CameraFlashModeMapping.persisted(from: .off) == CameraFlashModePersistence.off)
        #expect(CameraFlashModeMapping.persisted(from: .on) == CameraFlashModePersistence.on)
        #expect(CameraFlashModeMapping.persisted(from: .auto) == CameraFlashModePersistence.auto)
        #expect(CameraFlashModeMapping.persisted(from: .torch) == CameraFlashModePersistence.torch)
    }

    @Test
    func `round-trip — enum → 문자열 → enum 정공 보존`() {
        for mode in [CameraFlashMode.off, .on, .auto, .torch] {
            let persisted = CameraFlashModeMapping.persisted(from: mode)
            let restored = CameraFlashModeMapping.flashMode(from: persisted)
            #expect(restored == mode)
        }
    }
}
