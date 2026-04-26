import Foundation
@testable import PairShot
import SwiftData
import XCTest

@MainActor
final class AfterZoomRestoreTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testPhotoPairRoundTripsCameraSettings() throws {
        let camera = CameraSettings(
            zoomFactor: 2.5,
            lensPosition: .backWide,
            flashMode: .off,
            useGrid: false,
            useNightMode: false
        )
        let pair = PhotoPair(beforeFileName: "z.jpg", cameraSettings: camera)
        context.insert(pair)
        try context.save()

        XCTAssertEqual(pair.cameraSettings?.zoomFactor, 2.5, accuracy: 1e-9)
        XCTAssertEqual(pair.cameraSettings?.lensPosition, .backWide)
    }

    func testSettingZoomFactorOnFreshSessionIsSafe() async {
        let session = CameraSession()
        await session.setZoomFactor(2.0)
        let current = await session.currentZoomFactor
        XCTAssertEqual(current, 1.0, accuracy: 1e-9)
    }

    func testRampToZoomFactorOnFreshSessionIsSafe() async {
        let session = CameraSession()
        await session.ramp(toZoomFactor: 3.0, rate: 4.0)
        let current = await session.currentZoomFactor
        XCTAssertEqual(current, 1.0, accuracy: 1e-9)
    }

    func testDefaultCameraSettingsAreNilOnFreshPair() {
        let pair = PhotoPair(beforeFileName: "d.jpg")
        XCTAssertNil(pair.cameraSettings)
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
