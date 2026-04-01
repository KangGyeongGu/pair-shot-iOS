import Testing
import AVFoundation
@testable import PairShot

@MainActor
struct CameraSettingsTests {

    // MARK: - cycleAspectRatio

    @Test func cycleAspectRatio_happyPath_4_3To16_9() {
        let settings = CameraSettings()
        settings.cycleAspectRatio()
        #expect(settings.currentAspectRatio == .ratio16_9)
    }

    @Test func cycleAspectRatio_boundary_16_9To1_1() {
        let settings = CameraSettings()
        settings.cycleAspectRatio() // 4:3 → 16:9
        settings.cycleAspectRatio() // 16:9 → 1:1
        #expect(settings.currentAspectRatio == .ratio1_1)
    }

    @Test func cycleAspectRatio_boundary_1_1WrapsTo4_3() {
        let settings = CameraSettings()
        settings.cycleAspectRatio() // → 16:9
        settings.cycleAspectRatio() // → 1:1
        settings.cycleAspectRatio() // → 4:3 (wrap)
        #expect(settings.currentAspectRatio == .ratio4_3)
    }

    @Test func cycleAspectRatio_fullCycle_returnsToInitial() {
        let settings = CameraSettings()
        let initial = settings.currentAspectRatio
        for _ in AspectRatio.allCases {
            settings.cycleAspectRatio()
        }
        #expect(settings.currentAspectRatio == initial)
    }

    // MARK: - cycleFlashMode

    @Test func cycleFlashMode_happyPath_autoToOn() {
        let settings = CameraSettings()
        // 초기값 .auto
        settings.cycleFlashMode()
        #expect(settings.flashMode == .on)
    }

    @Test func cycleFlashMode_boundary_onToOff() {
        let settings = CameraSettings()
        settings.cycleFlashMode() // → .on
        settings.cycleFlashMode() // → .off
        #expect(settings.flashMode == .off)
    }

    @Test func cycleFlashMode_boundary_offWrapsToAuto() {
        let settings = CameraSettings()
        settings.cycleFlashMode() // → .on
        settings.cycleFlashMode() // → .off
        settings.cycleFlashMode() // → .auto (wrap)
        #expect(settings.flashMode == .auto)
    }

    @Test func cycleFlashMode_fullCycle_returnsToAuto() {
        let settings = CameraSettings()
        settings.cycleFlashMode() // auto → on
        settings.cycleFlashMode() // on   → off
        settings.cycleFlashMode() // off  → auto
        #expect(settings.flashMode == .auto)
    }

    // MARK: - cycleTimer

    @Test func cycleTimer_happyPath_offTo3s() {
        let settings = CameraSettings()
        settings.cycleTimer()
        #expect(settings.timerDuration == .threeSeconds)
    }

    @Test func cycleTimer_boundary_3sTo10s() {
        let settings = CameraSettings()
        settings.cycleTimer() // → 3s
        settings.cycleTimer() // → 10s
        #expect(settings.timerDuration == .tenSeconds)
    }

    @Test func cycleTimer_boundary_10sWrapsToOff() {
        let settings = CameraSettings()
        settings.cycleTimer() // → 3s
        settings.cycleTimer() // → 10s
        settings.cycleTimer() // → off (wrap)
        #expect(settings.timerDuration == .off)
    }

    @Test func cycleTimer_fullCycle_returnsToOff() {
        let settings = CameraSettings()
        let initial = settings.timerDuration
        for _ in TimerDuration.allCases {
            settings.cycleTimer()
        }
        #expect(settings.timerDuration == initial)
    }

    // MARK: - toggleGrid

    @Test func toggleGrid_happyPath_falseToTrue() {
        let settings = CameraSettings()
        #expect(settings.isGridEnabled == false)
        settings.toggleGrid()
        #expect(settings.isGridEnabled == true)
    }

    @Test func toggleGrid_boundary_trueToFalse() {
        let settings = CameraSettings()
        settings.toggleGrid()
        settings.toggleGrid()
        #expect(settings.isGridEnabled == false)
    }

    @Test func toggleGrid_negative_singleCallChangesState() {
        let settings = CameraSettings()
        let before = settings.isGridEnabled
        settings.toggleGrid()
        #expect(settings.isGridEnabled == !before)
    }

    @Test func toggleGrid_multipleToggles_alternates() {
        let settings = CameraSettings()
        for i in 0..<4 {
            #expect(settings.isGridEnabled == (i % 2 != 0))
            settings.toggleGrid()
        }
    }

    // MARK: - setFrontCamera

    @Test func setFrontCamera_happyPath_setTrue() {
        let settings = CameraSettings()
        settings.setFrontCamera(true)
        #expect(settings.isUsingFrontCamera == true)
    }

    @Test func setFrontCamera_happyPath_setFalse() {
        let settings = CameraSettings()
        settings.setFrontCamera(true)
        settings.setFrontCamera(false)
        #expect(settings.isUsingFrontCamera == false)
    }

    @Test func setFrontCamera_boundary_setTrueTwiceIsIdempotent() {
        let settings = CameraSettings()
        settings.setFrontCamera(true)
        settings.setFrontCamera(true)
        #expect(settings.isUsingFrontCamera == true)
    }

    @Test func setFrontCamera_negative_initialValueIsFalse() {
        let settings = CameraSettings()
        #expect(settings.isUsingFrontCamera == false)
    }
}
