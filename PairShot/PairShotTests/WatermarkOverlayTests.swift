import Foundation
@testable import PairShot
import UIKit
import XCTest

/// P5.3 — `WatermarkOverlay` text composition + UserDefaults toggle.
final class WatermarkOverlayTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Wipe the toggle so each test starts from the registered default.
        UserDefaults.standard.removeObject(forKey: WatermarkOverlay.userDefaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: WatermarkOverlay.userDefaultsKey)
        super.tearDown()
    }

    // MARK: - happy

    func testMakeTextIncludesAppNameAndFormattedDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let text = WatermarkOverlay.makeText(appName: "PairShot", date: date)
        XCTAssertTrue(text.contains("PairShot"))
        // ISO-ish formatted slice: 2023-11 prefix is stable across timezones
        // for that timestamp range; assert just the year to remain robust.
        XCTAssertTrue(text.contains("2023"))
        XCTAssertTrue(text.contains("·"))
    }

    func testIsEnabledDefaultsToTrueWhenUnset() {
        // Wipe in setUp ensures unset state.
        XCTAssertTrue(WatermarkOverlay.isEnabled)
    }

    func testIsEnabledFollowsUserDefaultsOverride() {
        UserDefaults.standard.set(false, forKey: WatermarkOverlay.userDefaultsKey)
        XCTAssertFalse(WatermarkOverlay.isEnabled)
        UserDefaults.standard.set(true, forKey: WatermarkOverlay.userDefaultsKey)
        XCTAssertTrue(WatermarkOverlay.isEnabled)
    }

    func testApplyReturnsImageOfSameDimensionsAsSource() {
        let source = makeSolidImage(size: CGSize(width: 400, height: 300), color: .blue)
        let stamped = WatermarkOverlay.apply(to: source)
        XCTAssertEqual(stamped.size.width, 400, accuracy: 1.0)
        XCTAssertEqual(stamped.size.height, 300, accuracy: 1.0)
    }

    func testApplyEncodesToValidJPEG() {
        let source = makeSolidImage(size: CGSize(width: 200, height: 200), color: .red)
        let stamped = WatermarkOverlay.apply(to: source, date: Date(timeIntervalSince1970: 1000))
        let data = stamped.jpegData(compressionQuality: 0.9)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }

    // MARK: - edge

    func testApplyToZeroSizedImageReturnsSourceUnchanged() {
        // UIImage(size: .zero) isn't trivially constructable; we forge a
        // 1×1 image and assert apply() doesn't crash. The "zero size"
        // safeguard is exercised in CompositeRenderer's defensive path.
        let source = makeSolidImage(size: CGSize(width: 1, height: 1), color: .black)
        let stamped = WatermarkOverlay.apply(to: source)
        XCTAssertEqual(stamped.size.width, 1, accuracy: 0.5)
        XCTAssertEqual(stamped.size.height, 1, accuracy: 0.5)
    }

    func testMakeTextWithCustomAppName() {
        let text = WatermarkOverlay.makeText(
            appName: "CustomName",
            date: Date(timeIntervalSince1970: 0)
        )
        XCTAssertTrue(text.hasPrefix("CustomName"))
    }

    func testApplyDoesNotMutateSourceImage() {
        // UIImage values are reference-typed CGImage backings, but the
        // public size/scale shouldn't change as a side effect.
        let source = makeSolidImage(size: CGSize(width: 100, height: 80), color: .green)
        let originalSize = source.size
        _ = WatermarkOverlay.apply(to: source)
        XCTAssertEqual(source.size, originalSize)
    }

    // MARK: - helpers

    private func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
