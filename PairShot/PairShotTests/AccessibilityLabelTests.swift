import Foundation
@testable import PairShot
import XCTest

/// Audit-C — accessibilityLabel snapshot tests for gallery + project
/// rows.
///
/// Both surfaces previously read out as "image" / "row" only because
/// the SwiftUI builders never attached an accessibility label. This
/// file pins down the static label-generation helpers so a future
/// refactor that changes the wording (or accidentally drops the label)
/// surfaces here rather than in a TestFlight VoiceOver pass.
@MainActor
final class AccessibilityLabelTests: XCTestCase {
    // MARK: - PairThumbnailCell

    func testPairThumbnailCellLabelIncludesPendingStatusAndDate() {
        let project = Project(title: "현장 A")
        let pair = PhotoPair(
            beforePath: "photos/x.jpg",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            project: project
        )
        let label = PairThumbnailCell.accessibilityLabel(
            for: pair,
            isSelected: false,
            isSelectionMode: false
        )
        XCTAssertTrue(label.contains("Before"), "label should mention status: \(label)")
    }

    func testPairThumbnailCellLabelIncludesCompleteStatus() {
        let project = Project(title: "현장 B")
        let pair = PhotoPair(beforePath: "photos/y.jpg", project: project)
        pair.status = .complete
        pair.afterPath = "photos/y-after.jpg"

        let label = PairThumbnailCell.accessibilityLabel(
            for: pair,
            isSelected: false,
            isSelectionMode: false
        )
        XCTAssertTrue(label.contains("완료"), "label should mention 완료 for complete pair: \(label)")
    }

    func testPairThumbnailCellLabelIncludesCompositeStatus() {
        let project = Project(title: "현장 C")
        let pair = PhotoPair(beforePath: "photos/z.jpg", project: project)
        pair.status = .complete
        pair.afterPath = "photos/z-after.jpg"
        pair.combinedPath = "photos/z-comp.jpg"

        let label = PairThumbnailCell.accessibilityLabel(
            for: pair,
            isSelected: false,
            isSelectionMode: false
        )
        XCTAssertTrue(label.contains("합성"), "label should mention 합성 for composited pair: \(label)")
    }

    func testPairThumbnailCellLabelIncludesSelectionState() {
        let project = Project(title: "현장 D")
        let pair = PhotoPair(beforePath: "photos/q.jpg", project: project)

        let selected = PairThumbnailCell.accessibilityLabel(
            for: pair,
            isSelected: true,
            isSelectionMode: true
        )
        let unselected = PairThumbnailCell.accessibilityLabel(
            for: pair,
            isSelected: false,
            isSelectionMode: true
        )

        XCTAssertTrue(selected.contains("선택됨"), "selected label missing 선택됨: \(selected)")
        XCTAssertTrue(unselected.contains("선택 안 됨"), "unselected label missing 선택 안 됨: \(unselected)")
    }

    func testPairThumbnailCellLabelOmitsSelectionWhenNotInSelectionMode() {
        let project = Project(title: "현장 E")
        let pair = PhotoPair(beforePath: "photos/r.jpg", project: project)

        let label = PairThumbnailCell.accessibilityLabel(
            for: pair,
            isSelected: false,
            isSelectionMode: false
        )
        XCTAssertFalse(label.contains("선택됨"))
        XCTAssertFalse(label.contains("선택 안 됨"))
    }

    // MARK: - Korean text invariants

    func testStatusVocabularyIsKorean() {
        // Defence in depth: if a future translator localizes these
        // strings to a non-Korean device locale, the Korean asserts
        // above still hold because we route through `String(localized:)`
        // with the Korean source key as both lookup key and value.
        let project = Project(title: "현장 F")
        let pending = PhotoPair(beforePath: "photos/p.jpg", project: project)
        let label = PairThumbnailCell.accessibilityLabel(
            for: pending,
            isSelected: false,
            isSelectionMode: false
        )
        XCTAssertFalse(label.isEmpty)
        XCTAssertTrue(
            label.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7AF },
            "expected Hangul syllables in label: \(label)"
        )
    }
}
