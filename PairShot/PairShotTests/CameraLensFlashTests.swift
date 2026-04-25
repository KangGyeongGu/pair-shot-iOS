@preconcurrency import AVFoundation
@testable import PairShot
import XCTest

/// P2.3 — lens switch + 4-mode flash cycle.
final class CameraLensFlashTests: XCTestCase {
    // MARK: - happy

    func testFlashModeCycleIsFourStepsClosed() {
        // off → on → auto → torch → off
        var current: CameraFlashMode = .off
        for expected in [CameraFlashMode.on, .auto, .torch, .off] {
            current = current.next
            XCTAssertEqual(current, expected, "Cycle step landed on \(current.rawValue)")
        }
    }

    func testInitialLensIsBack() async {
        let session = CameraSession()
        let pos = await session.lensPosition
        XCTAssertEqual(pos, .back)
    }

    func testFlashStartsOff() async {
        let session = CameraSession()
        let mode = await session.flashMode
        XCTAssertEqual(mode, .off)
    }

    func testCycleFlashModeAdvances() async {
        let session = CameraSession()
        let after = await session.cycleFlashMode()
        XCTAssertEqual(after, .on, "First cycle from default .off must land on .on")
        let mode = await session.flashMode
        XCTAssertEqual(mode, .on)
    }

    // MARK: - edge

    func testSwitchLensWithoutConfigureIsNoOp() async {
        // start() never called → didConfigure stays false → no input attached
        // and switchLens must not crash or alter lensPosition.
        let session = CameraSession()
        await session.switchLens(to: .front)
        let pos = await session.lensPosition
        XCTAssertEqual(pos, .back, "switchLens before configure must remain on .back")
    }

    func testSetFlashModeIsIdempotent() async {
        let session = CameraSession()
        await session.setFlashMode(.auto)
        await session.setFlashMode(.auto)
        let mode = await session.flashMode
        XCTAssertEqual(mode, .auto)
    }
}
