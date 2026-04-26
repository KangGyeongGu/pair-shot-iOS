import Foundation
@testable import PairShot
import XCTest

final class FileNameBuilderTests: XCTestCase {
    private let timestamp = Date(timeIntervalSince1970: 1_745_657_412)

    func testBeforeProducesSpecPattern() throws {
        let id = try XCTUnwrap(UUID(uuidString: "A1B2C3D4-0000-0000-0000-000000000000"))
        let name = FileNameBuilder.before(prefix: "현장A", timestamp: timestamp, pairId: id)
        XCTAssertTrue(name.hasPrefix("현장A_before_"))
        XCTAssertTrue(name.hasSuffix("_a1b2c3.jpg"))
    }

    func testAfterUsesSameShortIdAsBefore() {
        let id = UUID()
        let beforeName = FileNameBuilder.before(prefix: "site", timestamp: timestamp, pairId: id)
        let afterName = FileNameBuilder.after(prefix: "site", timestamp: timestamp, pairId: id)
        let combinedName = FileNameBuilder.combined(prefix: "site", timestamp: timestamp, pairId: id)
        let shortId = FileNameBuilder.shortId(from: id)
        XCTAssertTrue(beforeName.contains(shortId))
        XCTAssertTrue(afterName.contains(shortId))
        XCTAssertTrue(combinedName.contains(shortId))
    }

    func testEmptyPrefixOmitsLeadingUnderscore() {
        let id = UUID()
        let name = FileNameBuilder.before(prefix: "", timestamp: timestamp, pairId: id)
        XCTAssertTrue(name.hasPrefix("before_"))
    }

    func testKoreanPrefixSurvivesSanitization() {
        let id = UUID()
        let name = FileNameBuilder.before(prefix: "현장 A", timestamp: timestamp, pairId: id)
        XCTAssertTrue(name.hasPrefix("현장 A_before_"))
    }

    func testForbiddenCharactersInPrefixAreScrubbed() {
        let id = UUID()
        let name = FileNameBuilder.before(prefix: "a/b\\c:d", timestamp: timestamp, pairId: id)
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains("\\"))
        XCTAssertFalse(name.contains(":"))
        XCTAssertTrue(name.hasPrefix("abcd_before_"))
    }

    func testDifferentPairIdsProduceDifferentShortIds() {
        let id1 = UUID()
        let id2 = UUID()
        let s1 = FileNameBuilder.shortId(from: id1)
        let s2 = FileNameBuilder.shortId(from: id2)
        XCTAssertNotEqual(s1, s2)
        XCTAssertEqual(s1.count, FileNameBuilder.shortIdLength)
    }

    func testThumbnailFileNameAppendsThumbSuffix() {
        let base = "site_before_20260426_153012_a1b2c3.jpg"
        let thumb = FileNameBuilder.thumbnail(forBaseName: base)
        XCTAssertEqual(thumb, "site_before_20260426_153012_a1b2c3_thumb.jpg")
    }

    func testThumbnailFileNameWithoutExtensionDefaultsToJpg() {
        let thumb = FileNameBuilder.thumbnail(forBaseName: "raw")
        XCTAssertEqual(thumb, "raw_thumb.jpg")
    }

    func testTimestampFormatMatchesSpec() {
        // 2026-04-26 06:50:12 UTC → varies by tz, but format is yyyyMMdd_HHmmss
        let formatter = FileNameBuilder.makeFormatter()
        let stamp = formatter.string(from: timestamp)
        XCTAssertEqual(stamp.count, "yyyyMMdd_HHmmss".count)
        XCTAssertTrue(stamp.contains("_"))
    }

    deinit {}
}
