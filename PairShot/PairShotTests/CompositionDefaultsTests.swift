import Foundation
@testable import PairShot
import XCTest

/// P8.3 — pure helpers behind the composition-settings UI.
///
/// `CompositionDefaults` owns alpha clamping + composite-layout raw
/// value parsing. The settings view + AppSettings binding both route
/// through these functions, so verifying them here covers the entire
/// "stored value → UI" path without spinning up SwiftUI.
final class CompositionDefaultsTests: XCTestCase {
    // MARK: - clampAlpha — happy

    func testClampAlphaPassesThroughInRangeValues() {
        XCTAssertEqual(CompositionDefaults.clampAlpha(0.0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(CompositionDefaults.clampAlpha(0.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(CompositionDefaults.clampAlpha(0.75), 0.75, accuracy: 1e-9)
        XCTAssertEqual(CompositionDefaults.clampAlpha(1.0), 1.0, accuracy: 1e-9)
    }

    // MARK: - clampAlpha — edge

    func testClampAlphaSnapsBelowZeroToZero() {
        XCTAssertEqual(CompositionDefaults.clampAlpha(-0.1), 0.0, accuracy: 1e-9)
        XCTAssertEqual(CompositionDefaults.clampAlpha(-9999), 0.0, accuracy: 1e-9)
    }

    func testClampAlphaSnapsAboveOneToOne() {
        XCTAssertEqual(CompositionDefaults.clampAlpha(1.0001), 1.0, accuracy: 1e-9)
        XCTAssertEqual(CompositionDefaults.clampAlpha(42), 1.0, accuracy: 1e-9)
    }

    func testClampAlphaCollapsesNonFiniteToFallback() {
        XCTAssertEqual(
            CompositionDefaults.clampAlpha(.nan),
            CompositionDefaults.fallbackAlpha,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            CompositionDefaults.clampAlpha(.infinity),
            CompositionDefaults.fallbackAlpha,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            CompositionDefaults.clampAlpha(-.infinity),
            CompositionDefaults.fallbackAlpha,
            accuracy: 1e-9
        )
    }

    // MARK: - layout(forRawValue:) — happy

    func testLayoutResolvesKnownRawValues() {
        XCTAssertEqual(CompositionDefaults.layout(forRawValue: "horizontal"), .horizontal)
        XCTAssertEqual(CompositionDefaults.layout(forRawValue: "vertical"), .vertical)
    }

    func testLayoutRoundTripsCaseRawValue() {
        for layout in CompositeLayout.allCases {
            XCTAssertEqual(
                CompositionDefaults.layout(forRawValue: layout.rawValue),
                layout,
                "rawValue round trip failed for \(layout)"
            )
        }
    }

    // MARK: - layout(forRawValue:) — edge

    func testLayoutFallsBackForEmptyOrUnknownRawValues() {
        XCTAssertEqual(
            CompositionDefaults.layout(forRawValue: ""),
            CompositionDefaults.fallbackLayout
        )
        XCTAssertEqual(
            CompositionDefaults.layout(forRawValue: "diagonal"),
            CompositionDefaults.fallbackLayout
        )
        XCTAssertEqual(
            CompositionDefaults.layout(forRawValue: "HORIZONTAL"),
            CompositionDefaults.fallbackLayout,
            "Raw values are case-sensitive — uppercase must not match"
        )
    }

    func testFallbackLayoutMatchesCompositeOptionsDefault() {
        XCTAssertEqual(
            CompositionDefaults.fallbackLayout,
            CompositeOptions.default.layout,
            "Settings UI default must match the renderer's `default` so the menu and the renderer agree."
        )
    }

    func testAlphaRangeBoundsAreSensible() {
        XCTAssertEqual(CompositionDefaults.alphaRange.lowerBound, 0.0, accuracy: 1e-9)
        XCTAssertEqual(CompositionDefaults.alphaRange.upperBound, 1.0, accuracy: 1e-9)
    }
}
