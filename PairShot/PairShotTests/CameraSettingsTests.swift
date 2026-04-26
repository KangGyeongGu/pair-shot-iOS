import Foundation
@testable import PairShot
import XCTest

final class CameraSettingsTests: XCTestCase {
    func testDefaultsAreSensibleForBackWideCamera() {
        let settings = CameraSettings()
        XCTAssertEqual(settings.zoomFactor, 1.0, accuracy: 1e-9)
        XCTAssertEqual(settings.lensPosition, .backWide)
        XCTAssertEqual(settings.flashMode, .off)
        XCTAssertFalse(settings.useGrid)
        XCTAssertFalse(settings.useNightMode)
    }

    func testEncodingDecodingRoundTrip() throws {
        let original = CameraSettings(
            zoomFactor: 2.5,
            lensPosition: .backTele,
            flashMode: .auto,
            useGrid: true,
            useNightMode: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CameraSettings.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testLensPositionRawValuesMatchSpec() {
        XCTAssertEqual(LensPosition.front.rawValue, "front")
        XCTAssertEqual(LensPosition.backWide.rawValue, "backWide")
        XCTAssertEqual(LensPosition.backUltraWide.rawValue, "backUltraWide")
        XCTAssertEqual(LensPosition.backTele.rawValue, "backTele")
    }

    func testFlashModeAllCases() {
        XCTAssertEqual(FlashMode.allCases, [.off, .on, .auto, .torch])
    }

    func testCameraSettingsRoundTripsThroughPhotoPair() {
        let pair = PhotoPair(
            beforeFileName: "x.jpg",
            cameraSettings: CameraSettings(
                zoomFactor: 5.0,
                lensPosition: .backTele,
                flashMode: .torch,
                useGrid: true,
                useNightMode: false
            )
        )
        XCTAssertEqual(pair.cameraSettings?.zoomFactor, 5.0)
        XCTAssertEqual(pair.cameraSettings?.lensPosition, .backTele)
        XCTAssertEqual(pair.cameraSettings?.flashMode, .torch)
        XCTAssertEqual(pair.cameraSettings?.useGrid, true)
    }

    func testPairWithoutCameraSettingsReturnsNil() {
        let pair = PhotoPair(beforeFileName: "x.jpg")
        XCTAssertNil(pair.cameraSettings)
    }

    deinit {}
}
