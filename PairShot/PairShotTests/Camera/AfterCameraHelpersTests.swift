import Foundation
@testable import PairShot
import Testing

@MainActor
struct AfterCameraHelpersTests {
    @Test
    func `InitialPairResolver — initialPairId 가 nil 이면 pending 의 첫 번째 반환`() {
        let pairA = PhotoPair()
        let pairB = PhotoPair()
        let result = AfterCameraInitialPairResolver.resolve(initialPairId: nil, pending: [pairA, pairB])
        #expect(result?.id == pairA.id)
    }

    @Test
    func `InitialPairResolver — initialPairId 가 pending 에 있으면 매칭 pair 반환`() {
        let pairA = PhotoPair()
        let pairB = PhotoPair()
        let result = AfterCameraInitialPairResolver.resolve(initialPairId: pairB.id, pending: [pairA, pairB])
        #expect(result?.id == pairB.id)
    }

    @Test
    func `InitialPairResolver — initialPairId 가 pending 에 없으면 첫 번째로 fallback`() {
        let pairA = PhotoPair()
        let pairB = PhotoPair()
        let unknown = UUID()
        let result = AfterCameraInitialPairResolver.resolve(initialPairId: unknown, pending: [pairA, pairB])
        #expect(result?.id == pairA.id)
    }

    @Test
    func `InitialPairResolver — pending 이 빈 배열이면 nil 반환`() {
        let result = AfterCameraInitialPairResolver.resolve(initialPairId: UUID(), pending: [])
        #expect(result == nil)
    }

    @Test
    func `ZoomPresetMatcher — presets 가 빈 배열이면 nil 반환`() {
        let result = AfterCameraZoomPresetMatcher.match(2.0, in: [])
        #expect(result == nil)
    }

    @Test
    func `ZoomPresetMatcher — factor 가 모든 preset 보다 작으면 첫 번째 preset 반환`() {
        let presets = [
            ZoomPresetSpec(id: "1x", factor: 1.0, label: "1x"),
            ZoomPresetSpec(id: "2x", factor: 2.0, label: "2x"),
        ]
        let result = AfterCameraZoomPresetMatcher.match(0.5, in: presets)
        #expect(result?.factor == 1.0)
    }

    @Test
    func `ZoomPresetMatcher — factor 가 정확히 preset 일치 시 그 preset 반환`() {
        let presets = [
            ZoomPresetSpec(id: "1x", factor: 1.0, label: "1x"),
            ZoomPresetSpec(id: "2x", factor: 2.0, label: "2x"),
            ZoomPresetSpec(id: "5x", factor: 5.0, label: "5x"),
        ]
        let result = AfterCameraZoomPresetMatcher.match(2.0, in: presets)
        #expect(result?.factor == 2.0)
    }

    @Test
    func `ZoomPresetMatcher — factor 사이의 값은 lower preset 매칭 (greatest≤factor+tolerance)`() {
        let presets = [
            ZoomPresetSpec(id: "1x", factor: 1.0, label: "1x"),
            ZoomPresetSpec(id: "2x", factor: 2.0, label: "2x"),
            ZoomPresetSpec(id: "5x", factor: 5.0, label: "5x"),
        ]
        let result = AfterCameraZoomPresetMatcher.match(3.5, in: presets)
        #expect(result?.factor == 2.0)
    }

    @Test
    func `ZoomPresetMatcher — tolerance 0_05 근사 매칭 (factor 가 preset_minus_0_04 일 때 그 preset 매칭)`() {
        let presets = [
            ZoomPresetSpec(id: "1x", factor: 1.0, label: "1x"),
            ZoomPresetSpec(id: "2x", factor: 2.0, label: "2x"),
        ]
        let result = AfterCameraZoomPresetMatcher.match(1.96, in: presets)
        #expect(result?.factor == 2.0)
    }

    @Test
    func `ZoomPresetMatcher — factor 가 최대 preset 보다 크면 최대 preset 반환`() {
        let presets = [
            ZoomPresetSpec(id: "1x", factor: 1.0, label: "1x"),
            ZoomPresetSpec(id: "2x", factor: 2.0, label: "2x"),
        ]
        let result = AfterCameraZoomPresetMatcher.match(10.0, in: presets)
        #expect(result?.factor == 2.0)
    }

    @Test
    func `CaptureErrorMessages — CameraSessionError 는 capture_failed`() {
        let message = AfterCameraCaptureErrorMessages.text(for: CameraSessionError.notConfigured)
        #expect(message == String(localized: "camera_error_capture_failed"))
    }

    @Test
    func `CaptureErrorMessages — CaptureAfterError_pairNotFound 는 persist_failed`() {
        let message = AfterCameraCaptureErrorMessages.text(for: CaptureAfterUseCase.CaptureAfterError.pairNotFound)
        #expect(message == String(localized: "camera_error_persist_failed"))
    }

    @Test
    func `CaptureErrorMessages — NSCocoaError 는 no_disk_space`() {
        let cocoaError = NSError(domain: NSCocoaErrorDomain, code: 512, userInfo: nil)
        let message = AfterCameraCaptureErrorMessages.text(for: cocoaError)
        #expect(message == String(localized: "camera_error_no_disk_space"))
    }

    @Test
    func `CaptureErrorMessages — NSPOSIXError 는 no_disk_space`() {
        let posixError = NSError(domain: NSPOSIXErrorDomain, code: 28, userInfo: nil)
        let message = AfterCameraCaptureErrorMessages.text(for: posixError)
        #expect(message == String(localized: "camera_error_no_disk_space"))
    }

    @Test
    func `CaptureErrorMessages — 알 수 없는 에러는 unknown fallback`() {
        let unknown = NSError(domain: "com.example.weird", code: 999, userInfo: nil)
        let message = AfterCameraCaptureErrorMessages.text(for: unknown)
        #expect(message == String(localized: "camera_error_unknown"))
    }

    @Test
    func `ZoomHaptics — 동일 ratio 반복 시 didCrossMinor false`() {
        let first = AfterCameraZoomHaptics.evaluate(ratio: 1.2, lastMinorIndex: nil, lastMajorIndex: nil)
        let again = AfterCameraZoomHaptics.evaluate(
            ratio: 1.2,
            lastMinorIndex: first.minorIndex,
            lastMajorIndex: first.majorIndex,
        )
        #expect(!again.didCrossMinor)
    }

    @Test
    func `ZoomHaptics — minor tick 경계 넘으면 didCrossMinor true`() {
        let result = AfterCameraZoomHaptics.evaluate(ratio: 1.3, lastMinorIndex: 12, lastMajorIndex: 1)
        #expect(result.minorIndex == 13)
        #expect(result.didCrossMinor)
    }

    @Test
    func `ZoomHaptics — major tick 근처 (tolerance 0_05) 에서 majorIndex 변동 시 didCrossMajor true`() {
        let result = AfterCameraZoomHaptics.evaluate(ratio: 2.02, lastMinorIndex: 19, lastMajorIndex: 1)
        #expect(result.majorIndex == 2)
        #expect(result.didCrossMajor)
    }

    @Test
    func `ZoomHaptics — major tick 멀리 떨어진 위치 (예 2_3) 는 didCrossMajor false`() {
        let result = AfterCameraZoomHaptics.evaluate(ratio: 2.3, lastMinorIndex: 22, lastMajorIndex: 1)
        #expect(result.majorIndex == 2)
        #expect(!result.didCrossMajor)
    }

    @Test
    func `ZoomHaptics — 같은 majorIndex 면 didCrossMajor false (nearMajor 이어도)`() {
        let result = AfterCameraZoomHaptics.evaluate(ratio: 2.02, lastMinorIndex: 19, lastMajorIndex: 2)
        #expect(result.majorIndex == 2)
        #expect(!result.didCrossMajor)
    }
}
