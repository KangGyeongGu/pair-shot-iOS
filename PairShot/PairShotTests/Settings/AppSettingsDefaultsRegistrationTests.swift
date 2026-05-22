import Foundation
@testable import PairShot
import Testing

struct AppSettingsDefaultsRegistrationTests {
    @Test
    func `registry 는 카메라 플래시 기본을 CameraFlashModePersistence defaultRawValue 로 사용한다`() {
        let registry = AppSettingsDefaultsRegistration.registry

        #expect(registry[AppSettingsKeys.cameraFlashMode] as? String == CameraFlashModePersistence.defaultRawValue)
    }

    @Test
    func `registry 는 정렬 기본을 SortOrderPersistence defaultRawValue 로 사용한다`() {
        let registry = AppSettingsDefaultsRegistration.registry

        #expect(registry[AppSettingsKeys.homeSortOrder] as? String == SortOrderPersistence.defaultRawValue)
        #expect(registry[AppSettingsKeys.albumSortOrder] as? String == SortOrderPersistence.defaultRawValue)
    }

    @Test
    func `registry 는 카메라 그리드와 night 모드 기본 false`() {
        let registry = AppSettingsDefaultsRegistration.registry

        #expect(registry[AppSettingsKeys.cameraGridEnabled] as? Bool == false)
        #expect(registry[AppSettingsKeys.cameraLevelEnabled] as? Bool == false)
        #expect(registry[AppSettingsKeys.cameraNightMode] as? Bool == false)
    }

    @Test
    func `registry 는 overlayEnabled 와 embedGPSInPhoto 기본 true`() {
        let registry = AppSettingsDefaultsRegistration.registry

        #expect(registry[AppSettingsKeys.overlayEnabled] as? Bool == true)
        #expect(registry[AppSettingsKeys.embedGPSInPhoto] as? Bool == true)
    }

    @Test
    func `registry 는 export quality high 를 기본으로 한다`() {
        let registry = AppSettingsDefaultsRegistration.registry

        #expect(registry[AppSettingsKeys.exportQuality] as? String == ExportQuality.high.rawValue)
    }
}
