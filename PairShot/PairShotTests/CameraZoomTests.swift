@preconcurrency import AVFoundation
@testable import PairShot
import XCTest

/// P2.2 — pinch zoom + presets.
/// Most of the AVCaptureDevice surface is read-only; we exercise the
/// session's clamp/preset logic that doesn't need a real camera, and assert
/// the API contract on the Simulator (no input → safe no-ops, sane fallbacks).
final class CameraZoomTests: XCTestCase {
    // MARK: - happy

    func testZoomPresetsExposeExactFactors() {
        XCTAssertEqual(ZoomPreset.ultraWide.factor, 0.5, accuracy: 1e-9)
        XCTAssertEqual(ZoomPreset.wide.factor, 1.0, accuracy: 1e-9)
        XCTAssertEqual(ZoomPreset.tele2x.factor, 2.0, accuracy: 1e-9)
        XCTAssertEqual(ZoomPreset.tele5x.factor, 5.0, accuracy: 1e-9)
    }

    func testZoomPresetsLabelsAreUserVisible() {
        XCTAssertEqual(ZoomPreset.ultraWide.label, "0.5x")
        XCTAssertEqual(ZoomPreset.wide.label, "1x")
        XCTAssertEqual(ZoomPreset.tele2x.label, "2x")
        XCTAssertEqual(ZoomPreset.tele5x.label, "5x")
    }

    func testSimulatorSessionFallsBackToOneOneZoomRange() async {
        let session = CameraSession()
        let minZ = await session.minZoomFactor
        let maxZ = await session.maxZoomFactor
        XCTAssertEqual(minZ, 1.0, accuracy: 1e-9, "Without device, minZoom must default to 1.0")
        XCTAssertEqual(maxZ, 1.0, accuracy: 1e-9, "Without device, maxZoom must default to 1.0")
    }

    // MARK: - edge

    func testRampWithoutDeviceIsNoOp() async {
        // No camera on Simulator → ramp must not throw / crash.
        let session = CameraSession()
        await session.ramp(toZoomFactor: 3.5)
        let factor = await session.currentZoomFactor
        XCTAssertEqual(factor, 1.0, accuracy: 1e-9)
    }

    func testIsPresetSupportedFalseWhenNoDevice() async {
        let session = CameraSession()
        for preset in ZoomPreset.allCases {
            let supported = await session.isPresetSupported(preset)
            XCTAssertFalse(supported, "Preset \(preset.label) cannot be supported without a device")
        }
    }

    func testSetZoomFactorClampsInputWhenNoDevice() async {
        // Even with absurd input the actor must not crash.
        let session = CameraSession()
        await session.setZoomFactor(99.0)
        let factor = await session.currentZoomFactor
        XCTAssertEqual(factor, 1.0, accuracy: 1e-9)
    }
}
