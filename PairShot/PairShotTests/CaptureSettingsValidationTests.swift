import Foundation
@testable import PairShot
import XCTest

/// P8.2 — pure-function validation of `FileNamePrefixValidator`.
///
/// The settings UI funnels every user keystroke through `sanitize`
/// before persisting; correctness of these rules is what stops the user
/// from accidentally creating filenames with `/` in them on iOS (the
/// app container would happily accept "subdir/UUID.jpg" and break
/// downstream tools that expect a flat folder).
final class CaptureSettingsValidationTests: XCTestCase {
    // MARK: - happy

    func testSanitizeReturnsEmptyForBlankInput() {
        XCTAssertEqual(FileNamePrefixValidator.sanitize(""), "")
        XCTAssertEqual(FileNamePrefixValidator.sanitize("   "), "")
        XCTAssertEqual(FileNamePrefixValidator.sanitize("\t\n"), "")
    }

    func testSanitizeTrimsLeadingAndTrailingWhitespace() {
        XCTAssertEqual(FileNamePrefixValidator.sanitize("  site-A_  "), "site-A_")
        XCTAssertEqual(FileNamePrefixValidator.sanitize("\nfoo_\n"), "foo_")
    }

    func testSanitizeAllowsKoreanAndAlphanumeric() {
        XCTAssertEqual(FileNamePrefixValidator.sanitize("현장1_"), "현장1_")
        XCTAssertEqual(FileNamePrefixValidator.sanitize("Site-42_v2."), "Site-42_v2.")
    }

    // MARK: - edge

    func testSanitizeStripsForbiddenFilesystemCharacters() {
        XCTAssertEqual(FileNamePrefixValidator.sanitize("a/b\\c:d?e*f\"g<h>i|j"), "abcdefghij")
    }

    func testSanitizeDropsControlCharactersAndNewlinesInside() {
        XCTAssertEqual(FileNamePrefixValidator.sanitize("foo\nbar"), "foobar")
        XCTAssertEqual(FileNamePrefixValidator.sanitize("foo\u{07}bar"), "foobar")
    }

    func testSanitizeTruncatesAtMaxLength() {
        let oversized = String(repeating: "a", count: FileNamePrefixValidator.maxLength + 10)
        let result = FileNamePrefixValidator.sanitize(oversized)
        XCTAssertEqual(result.count, FileNamePrefixValidator.maxLength)
    }

    func testSanitizePreservesUnderscoreAndHyphenAndDot() {
        // These are common, valid filename characters and must survive.
        XCTAssertEqual(FileNamePrefixValidator.sanitize("a_b-c.d"), "a_b-c.d")
    }

    func testMaxLengthIsSensible() {
        // Sanity ceiling — UUID alone is 36 chars + ".jpg" = 41. Adding
        // 32-char prefix tops out at 73 which is well under FAT32's 255.
        XCTAssertGreaterThanOrEqual(FileNamePrefixValidator.maxLength, 16)
        XCTAssertLessThanOrEqual(FileNamePrefixValidator.maxLength, 64)
    }
}
