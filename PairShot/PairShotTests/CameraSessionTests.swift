@preconcurrency import AVFoundation
import XCTest
@testable import PairShot

final class CameraSessionTests: XCTestCase {
    // MARK: - happy path

    func testNewSessionIsNotRunning() async {
        let session = CameraSession()
        let running = await session.isRunning
        XCTAssertFalse(running, "Newly constructed CameraSession must not be running")
    }

    // MARK: - boundary

    func testStopBeforeStartDoesNotCrash() async {
        let session = CameraSession()
        await session.stop()
        let running = await session.isRunning
        XCTAssertFalse(running)
    }

    func testCaptureSessionReferenceIsStableAcrossCalls() {
        let session = CameraSession()
        let first = session.captureSession
        let second = session.captureSession
        XCTAssertTrue(first === second, "captureSession must return the same AVCaptureSession instance")
    }

    func testStartIsSafeOnSimulatorRegardlessOfCameraAvailability() async {
        let session = CameraSession()
        await session.start()

        let hasInput = await session.hasInput
        let isRunning = await session.isRunning

        // Simulator: no .builtInWideAngleCamera back device → hasInput == false, isRunning == false.
        // Real device with permission granted: hasInput == true, isRunning == true.
        // We cannot guarantee permission state in CI, so we only assert the invariant:
        // running implies input was attached.
        if isRunning {
            XCTAssertTrue(hasInput, "Session should not start running without an input")
        } else {
            // Either no device (simulator) or permission denied — either way no crash.
            XCTAssertTrue(true)
        }

        await session.stop()
    }

    // MARK: - integration

    func testAuthorizationStateMatchesSystemStatus() async {
        let session = CameraSession()
        let state = await session.authorizationState()
        let system = AVCaptureDevice.authorizationStatus(for: .video)

        switch (state, system) {
        case (.notDetermined, .notDetermined),
             (.authorized, .authorized),
             (.denied, .denied),
             (.restricted, .restricted):
            XCTAssertTrue(true)
        default:
            XCTFail("authorizationState() \(state) must mirror system status \(system.rawValue)")
        }
    }

    // MARK: - edge

    func testStartStopRepeatedThreeTimesEndsStopped() async {
        let session = CameraSession()
        for _ in 0 ..< 3 {
            await session.start()
            await session.stop()
        }
        let running = await session.isRunning
        XCTAssertFalse(running, "After balanced start/stop cycles, session must be stopped")
    }

    func testDistinctInstancesHaveDistinctCaptureSessions() {
        let a = CameraSession()
        let b = CameraSession()
        XCTAssertFalse(a.captureSession === b.captureSession,
                       "Each CameraSession must own its own AVCaptureSession")
    }

    // MARK: - preview view

    @MainActor
    func testCameraPreviewViewWiresSessionAndGravity() {
        let avSession = AVCaptureSession()
        let view = CameraPreviewView(session: avSession)

        XCTAssertTrue(view.previewLayer.session === avSession,
                      "Preview layer must reference the same AVCaptureSession")
        XCTAssertEqual(view.previewLayer.videoGravity, .resizeAspectFill)
        XCTAssertEqual(view.backgroundColor, .black)
    }
}
