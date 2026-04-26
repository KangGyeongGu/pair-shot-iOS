import Foundation
@testable import PairShot
import XCTest

/// P8.3 — UserDefaults round-trip for the composition-related properties
/// (`defaultOverlayAlpha`, `defaultCompositeLayout`, `watermarkEnabled`).
///
/// Each test scopes itself to a fresh `UserDefaults(suiteName:)` so we
/// don't bleed into `UserDefaults.standard`. The watermark key is
/// shared with the legacy `WatermarkOverlay.userDefaultsKey` so the
/// round-trip below also documents that contract.
@MainActor
final class AppSettingsCompositionTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "pairshot.tests.AppSettingsComposition.\(UUID().uuidString)"
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

    func testRegistersCompositionDefaultsOnInit() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(
            settings.defaultOverlayAlpha,
            CompositionDefaults.fallbackAlpha,
            accuracy: 1e-9
        )
        XCTAssertEqual(settings.defaultCompositeLayout, CompositionDefaults.fallbackLayout)
        XCTAssertEqual(settings.watermarkEnabled, WatermarkOverlay.defaultEnabled)
    }

    func testOverlayAlphaSetterPersistsClampedValue() {
        let settings = AppSettings(defaults: defaults)
        settings.defaultOverlayAlpha = 0.42
        XCTAssertEqual(
            defaults.double(forKey: AppSettings.defaultOverlayAlphaKey),
            0.42,
            accuracy: 1e-9
        )
    }

    func testOverlayAlphaSetterClampsOutOfRange() {
        let settings = AppSettings(defaults: defaults)

        settings.defaultOverlayAlpha = -2
        XCTAssertEqual(settings.defaultOverlayAlpha, 0.0, accuracy: 1e-9)
        XCTAssertEqual(
            defaults.double(forKey: AppSettings.defaultOverlayAlphaKey),
            0.0,
            accuracy: 1e-9
        )

        settings.defaultOverlayAlpha = 4
        XCTAssertEqual(settings.defaultOverlayAlpha, 1.0, accuracy: 1e-9)
    }

    func testCompositeLayoutSetterPersistsRawString() {
        let settings = AppSettings(defaults: defaults)
        settings.defaultCompositeLayout = .vertical
        XCTAssertEqual(
            defaults.string(forKey: AppSettings.defaultCompositeLayoutKey),
            "vertical"
        )

        settings.defaultCompositeLayout = .horizontal
        XCTAssertEqual(
            defaults.string(forKey: AppSettings.defaultCompositeLayoutKey),
            "horizontal"
        )
    }

    func testWatermarkEnabledSetterPersistsToSharedKey() {
        let settings = AppSettings(defaults: defaults)
        settings.watermarkEnabled = false
        XCTAssertFalse(defaults.bool(forKey: WatermarkOverlay.userDefaultsKey))
        XCTAssertFalse(settings.watermarkEnabled)

        settings.watermarkEnabled = true
        XCTAssertTrue(defaults.bool(forKey: WatermarkOverlay.userDefaultsKey))
        XCTAssertTrue(settings.watermarkEnabled)
    }

    // MARK: - edge

    func testTwoInstancesShareCompositionDefaultsBacking() {
        let first = AppSettings(defaults: defaults)
        first.defaultOverlayAlpha = 0.31
        first.defaultCompositeLayout = .vertical
        first.watermarkEnabled = false

        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.defaultOverlayAlpha, 0.31, accuracy: 1e-9)
        XCTAssertEqual(second.defaultCompositeLayout, .vertical)
        XCTAssertFalse(second.watermarkEnabled)
    }

    func testCorruptedLayoutRawValueFallsBackOnRead() {
        defaults.set("garbage", forKey: AppSettings.defaultCompositeLayoutKey)
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.defaultCompositeLayout, CompositionDefaults.fallbackLayout)
    }
}
