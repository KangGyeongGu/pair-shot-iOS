import Foundation
@testable import PairShot
import XCTest

@MainActor
final class AccessibilityLabelTests: XCTestCase {
    func testPairThumbnailCellLabelIncludesPendingStatusAndDate() {
        let pair = PhotoPair(
            beforeFileName: "x.jpg",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let label = PairThumbnailCell.accessibilityLabel(
            for: pair,
            isSelected: false,
            isSelectionMode: false
        )
        XCTAssertTrue(label.contains("Before"), "label should mention status: \(label)")
    }

    func testPairThumbnailCellLabelIncludesCompleteStatus() {
        let pair = PhotoPair(beforeFileName: "y.jpg")
        pair.afterFileName = "y-after.jpg"

        let label = PairThumbnailCell.accessibilityLabel(
            for: pair,
            isSelected: false,
            isSelectionMode: false
        )
        XCTAssertTrue(label.contains("완료"), "label should mention 완료 for captured pair: \(label)")
    }

    func testPairThumbnailCellLabelIncludesCompositeStatus() {
        let pair = PhotoPair(beforeFileName: "z.jpg")
        pair.afterFileName = "z-after.jpg"
        pair.combinedFileName = "z-comp.jpg"

        let label = PairThumbnailCell.accessibilityLabel(
            for: pair,
            isSelected: false,
            isSelectionMode: false
        )
        XCTAssertTrue(label.contains("합성"), "label should mention 합성 for composited pair: \(label)")
    }

    func testPairThumbnailCellLabelIncludesSelectionState() {
        let pair = PhotoPair(beforeFileName: "q.jpg")

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

        XCTAssertTrue(selected.contains("선택됨"))
        XCTAssertTrue(unselected.contains("선택 안 됨"))
    }

    func testPairThumbnailCellLabelOmitsSelectionWhenNotInSelectionMode() {
        let pair = PhotoPair(beforeFileName: "r.jpg")
        let label = PairThumbnailCell.accessibilityLabel(
            for: pair,
            isSelected: false,
            isSelectionMode: false
        )
        XCTAssertFalse(label.contains("선택됨"))
        XCTAssertFalse(label.contains("선택 안 됨"))
    }

    func testStatusVocabularyIsKorean() {
        let pending = PhotoPair(beforeFileName: "p.jpg")
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

    deinit {}
}
