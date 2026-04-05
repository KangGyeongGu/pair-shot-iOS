import CoreHaptics
@testable import PairShot
import Testing

@MainActor
struct HapticServiceTests {
    @Test func clampedIntensity_happyPath_midRangeValueIsSymmetric() {
        let result = HapticService.clampedIntensity(0.5)
        #expect(result == 0.5)
    }

    @Test func clampedIntensity_happyPath_oneProducesZeroIntensity() {
        let result = HapticService.clampedIntensity(1.0)
        #expect(result == 0.0)
    }

    @Test func clampedIntensity_happyPath_zeroProducesMaxIntensity() {
        let result = HapticService.clampedIntensity(0.0)
        #expect(result == 1.0)
    }

    @Test func clampedIntensity_happyPath_returnsInvertedFloat() {
        let result = HapticService.clampedIntensity(0.75)
        #expect(result == Float(0.25))
    }

    @Test func clampedIntensity_boundary_justBelowOneIsInverted() {
        let result = HapticService.clampedIntensity(0.999)
        #expect(result == Float(0.001))
    }

    @Test func clampedIntensity_boundary_justAboveZeroIsInverted() {
        let result = HapticService.clampedIntensity(0.001)
        #expect(result == Float(0.999))
    }

    @Test func clampedIntensity_boundary_exactlyOneClampedToZero() {
        let result = HapticService.clampedIntensity(1.0)
        #expect(result == 0.0)
    }

    @Test func clampedIntensity_boundary_exactlyZeroClampedToOne() {
        let result = HapticService.clampedIntensity(0.0)
        #expect(result == 1.0)
    }

    @Test func clampedIntensity_outOfRange_aboveOneClampedToZero() {
        let result = HapticService.clampedIntensity(1.5)
        #expect(result == 0.0)
    }

    @Test func clampedIntensity_outOfRange_largeValueClampedToZero() {
        let result = HapticService.clampedIntensity(100.0)
        #expect(result == 0.0)
    }

    @Test func clampedIntensity_outOfRange_belowZeroClampedToOne() {
        let result = HapticService.clampedIntensity(-0.1)
        #expect(result == 1.0)
    }

    @Test func clampedIntensity_outOfRange_largeNegativeClampedToOne() {
        let result = HapticService.clampedIntensity(-999.0)
        #expect(result == 1.0)
    }

    @Test func clampedIntensity_error_nanClampsToZero() {
        // Double.nan은 min/max 비교에서 항상 false이므로 max(0, min(nan, 1)) = 0
        let result = HapticService.clampedIntensity(Double.nan)
        #expect(result == 0.0)
    }

    @Test func supportsHaptics_simulator_isFalse() {
        // 시뮬레이터는 Core Haptics 하드웨어 미지원
        let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        #expect(supportsHaptics == false)
    }

    @Test func supportsHaptics_simulator_engineInitDoesNotCrash() {
        // 시뮬레이터에서 HapticService init이 안전하게 완료되어야 한다
        let service = HapticService()
        // init 완료 시점에 supportsHaptics == false 이므로 engine은 nil
        _ = service
    }

    @Test func supportsHaptics_simulator_stopHapticDoesNotCrash() {
        let service = HapticService()
        service.stopHaptic()
    }

    @Test func supportsHaptics_simulator_updateIntensityDoesNotCrashBelowThreshold() {
        let service = HapticService()
        // alignmentScore <= 0.1 이면 fallbackImpact를 호출하지 않음
        service.updateIntensity(alignmentScore: 0.05)
    }
}
