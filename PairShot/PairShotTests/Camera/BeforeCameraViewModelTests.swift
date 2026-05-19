import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct BeforeCameraViewModelTests {
    @Test
    func `captureErrorText — CameraSessionError 는 capture_failed 메시지`() {
        let message = BeforeCameraViewModel.captureErrorText(for: CameraSessionError.notConfigured)
        #expect(message == String(localized: "camera_error_capture_failed"))
    }

    @Test
    func `captureErrorText — NSCocoaErrorDomain 은 no_disk_space 메시지`() {
        let cocoaError = NSError(domain: NSCocoaErrorDomain, code: 512, userInfo: nil)
        let message = BeforeCameraViewModel.captureErrorText(for: cocoaError)
        #expect(message == String(localized: "camera_error_no_disk_space"))
    }

    @Test
    func `captureErrorText — NSPOSIXErrorDomain 은 no_disk_space 메시지`() {
        let posixError = NSError(domain: NSPOSIXErrorDomain, code: 28, userInfo: nil)
        let message = BeforeCameraViewModel.captureErrorText(for: posixError)
        #expect(message == String(localized: "camera_error_no_disk_space"))
    }

    @Test
    func `captureErrorText — 알 수 없는 도메인은 unknown 메시지로 fallback`() {
        let unknownError = NSError(domain: "com.example.weird", code: 999, userInfo: nil)
        let message = BeforeCameraViewModel.captureErrorText(for: unknownError)
        #expect(message == String(localized: "camera_error_unknown"))
    }

    @Test
    func `applyZoomSnapshot — snapshot 의 값들이 ViewModel state 로 정확히 매핑`() {
        let viewModel = makeViewModel()
        let snapshot = CameraZoomSnapshot(
            minFactor: 0.5,
            maxFactor: 10,
            currentFactor: 2.5,
            firstSwitchOver: 2.0,
            displayMultiplier: 0.5,
            presets: [],
            exposureBiasRange: -3.0 ... 3.0,
        )

        viewModel.applyZoomSnapshot(snapshot)

        #expect(viewModel.minZoom == 0.5)
        #expect(viewModel.maxZoom == 10)
        #expect(viewModel.currentZoomRatio == 2.5)
        #expect(viewModel.firstSwitchOver == 2.0)
        #expect(viewModel.displayMultiplier == 0.5)
        #expect(viewModel.cachedExposureRange == -3.0 ... 3.0)
    }

    @Test
    func `applyZoomSnapshot 의 empty snapshot 은 모든 zoom 값을 1로 reset`() {
        let viewModel = makeViewModel()
        viewModel.minZoom = 5
        viewModel.maxZoom = 20
        viewModel.currentZoomRatio = 10

        viewModel.applyZoomSnapshot(.empty)

        #expect(viewModel.minZoom == 1)
        #expect(viewModel.maxZoom == 1)
        #expect(viewModel.currentZoomRatio == 1)
        #expect(viewModel.cachedExposureRange == nil)
    }

    @Test
    func `flashMode didSet — 변경 시 appSettings 에 정공 문자열로 persist`() {
        let env = Self.makeEnv()
        let viewModel = env.makeBeforeCameraViewModel(albumId: nil)

        viewModel.flashMode = .on
        #expect(env.appSettings.cameraFlashMode == CameraFlashModePersistence.on)

        viewModel.flashMode = .auto
        #expect(env.appSettings.cameraFlashMode == CameraFlashModePersistence.auto)

        viewModel.flashMode = .off
        #expect(env.appSettings.cameraFlashMode == CameraFlashModePersistence.off)
    }

    @Test
    func `isGridOn didSet — appSettings 에 즉시 반영`() {
        let env = Self.makeEnv()
        let viewModel = env.makeBeforeCameraViewModel(albumId: nil)

        viewModel.isGridOn = true
        #expect(env.appSettings.cameraGridEnabled)

        viewModel.isGridOn = false
        #expect(!env.appSettings.cameraGridEnabled)
    }

    @Test
    func `isLevelOn didSet — appSettings 에 즉시 반영`() {
        let env = Self.makeEnv()
        let viewModel = env.makeBeforeCameraViewModel(albumId: nil)

        viewModel.isLevelOn = true
        #expect(env.appSettings.cameraLevelEnabled)

        viewModel.isLevelOn = false
        #expect(!env.appSettings.cameraLevelEnabled)
    }

    @Test
    func `init — appSettings 의 기존 값들로 properties 초기화`() {
        let env = Self.makeEnv()
        env.appSettings.cameraGridEnabled = true
        env.appSettings.cameraLevelEnabled = true
        env.appSettings.cameraNightMode = true
        env.appSettings.cameraFlashMode = CameraFlashModePersistence.auto

        let viewModel = env.makeBeforeCameraViewModel(albumId: nil)

        #expect(viewModel.isGridOn)
        #expect(viewModel.isLevelOn)
        #expect(viewModel.isNightModeOn)
        #expect(viewModel.flashMode == .auto)
    }

    @Test
    func `init — albumId 와 refillPairId 는 그대로 보존`() {
        let env = Self.makeEnv()
        let albumId = UUID()
        let refillPairId = UUID()

        let viewModel = env.makeBeforeCameraViewModel(albumId: albumId, refillPairId: refillPairId)

        #expect(viewModel.albumId == albumId)
        #expect(viewModel.refillPairId == refillPairId)
    }

    private func makeViewModel() -> BeforeCameraViewModel {
        Self.makeEnv().makeBeforeCameraViewModel(albumId: nil)
    }

    private static func makeEnv() -> AppEnvironment {
        let suiteName = "beforecamera-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let settings = AppSettings(defaults: defaults)
        return AppEnvironment(
            modelContainer: makeContainer(),
            appSettings: settings,
        )
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("test container failure: \(error)")
        }
    }
}
