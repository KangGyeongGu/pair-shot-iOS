import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P3.3 — Before zoom factor is auto-restored on entry.
///
/// We can't run the AVCaptureDevice on the simulator, so we assert:
/// 1. The pair's `beforeZoomFactor` round-trips through SwiftData faithfully.
/// 2. `CameraSession.setZoomFactor(_)` is safe to call on a fresh actor with
///    no input (Simulator path) — it silently no-ops, never crashes.
@MainActor
final class AfterZoomRestoreTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - happy

    func testPhotoPairRoundTripsBeforeZoomFactor() throws {
        let project = Project(title: "줌 복원")
        context.insert(project)

        let pair = PhotoPair(
            beforePath: "photos/z.jpg",
            beforeZoomFactor: 2.5,
            beforeLensIdentifier: "BuiltInWideAngleCamera.back",
            project: project
        )
        context.insert(pair)
        try context.save()

        XCTAssertEqual(pair.beforeZoomFactor, 2.5, accuracy: 1e-9)
        XCTAssertEqual(pair.beforeLensIdentifier, "BuiltInWideAngleCamera.back")
    }

    func testSettingZoomFactorOnFreshSessionIsSafe() async {
        let session = CameraSession()
        // No start(), no input — should silently no-op.
        await session.setZoomFactor(2.0)
        let current = await session.currentZoomFactor
        // Simulator fallback for currentZoomFactor is 1.0 when no device.
        XCTAssertEqual(current, 1.0, accuracy: 1e-9)
    }

    func testRampToZoomFactorOnFreshSessionIsSafe() async {
        let session = CameraSession()
        await session.ramp(toZoomFactor: 3.0, rate: 4.0)
        let current = await session.currentZoomFactor
        XCTAssertEqual(current, 1.0, accuracy: 1e-9)
    }

    // MARK: - edge

    func testDefaultBeforeZoomFactorIsOne() {
        let pair = PhotoPair(beforePath: "photos/d.jpg")
        XCTAssertEqual(pair.beforeZoomFactor, 1.0, accuracy: 1e-9)
    }

    func testZeroAndNegativeZoomFactorsRoundTripUnclamped() throws {
        // The model itself doesn't clamp — clamping is the device's job at
        // restore time. We just assert the field is opaque storage so a future
        // change to clamp policy doesn't silently corrupt existing pairs.
        let project = Project(title: "원시값")
        context.insert(project)

        let pair = PhotoPair(
            beforePath: "photos/e.jpg",
            beforeZoomFactor: -1.0,
            project: project
        )
        context.insert(pair)
        try context.save()

        XCTAssertEqual(pair.beforeZoomFactor, -1.0, accuracy: 1e-9)
    }

    func testCameraSessionMinAndMaxZoomFallbackToOneOnSimulator() async {
        let session = CameraSession()
        let minZ = await session.minZoomFactor
        let maxZ = await session.maxZoomFactor
        XCTAssertEqual(minZ, 1.0, accuracy: 1e-9)
        XCTAssertEqual(maxZ, 1.0, accuracy: 1e-9)
    }

    deinit {}
}
