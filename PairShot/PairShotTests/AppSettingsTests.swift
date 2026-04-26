import Foundation
@testable import PairShot
import XCTest

/// P8.1·P8.2 — `AppSettings` UserDefaults wrapper.
///
/// Each test gets a fresh in-memory `UserDefaults` (suite name uses the
/// test method's `name` property) so global preferences never bleed
/// between cases or other suites that touch `UserDefaults.standard`.
@MainActor
final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "pairshot.tests.AppSettings.\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Could not allocate isolated UserDefaults suite")
        }
        defaults = suite
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    // MARK: - happy

    func testInitRegistersDefaultsWhenUnset() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.jpegQuality, CaptureQualityPreset.standard.rawValue, accuracy: 1e-6)
        XCTAssertEqual(settings.fileNamePrefix, "")
    }

    func testJpegQualitySetterPersistsToUserDefaults() {
        let settings = AppSettings(defaults: defaults)
        settings.jpegQuality = CaptureQualityPreset.high.rawValue
        XCTAssertEqual(
            defaults.double(forKey: AppSettings.jpegQualityKey),
            CaptureQualityPreset.high.rawValue,
            accuracy: 1e-6
        )
    }

    func testFileNamePrefixSetterPersistsToUserDefaults() {
        let settings = AppSettings(defaults: defaults)
        settings.fileNamePrefix = "site-A_"
        XCTAssertEqual(defaults.string(forKey: AppSettings.fileNamePrefixKey), "site-A_")
    }

    func testTwoInstancesShareUserDefaultsBacking() {
        let first = AppSettings(defaults: defaults)
        first.jpegQuality = CaptureQualityPreset.low.rawValue
        first.fileNamePrefix = "shared-"

        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.jpegQuality, CaptureQualityPreset.low.rawValue, accuracy: 1e-6)
        XCTAssertEqual(second.fileNamePrefix, "shared-")
    }

    // MARK: - edge

    func testCaptureQualityPresetNearestRoundsToClosestStep() {
        XCTAssertEqual(CaptureQualityPreset.nearest(to: 0.55), .low)
        XCTAssertEqual(CaptureQualityPreset.nearest(to: 0.79), .standard)
        XCTAssertEqual(CaptureQualityPreset.nearest(to: 0.94), .high)
        // Mid-points: should still pick a preset deterministically.
        XCTAssertNotNil(CaptureQualityPreset.nearest(to: 0.0))
        XCTAssertNotNil(CaptureQualityPreset.nearest(to: 1.0))
    }

    func testCaptureQualityPresetCasesCoverThreeStops() {
        let raws = CaptureQualityPreset.allCases.map(\.rawValue)
        XCTAssertEqual(raws, [0.6, 0.8, 0.95])
    }
}
