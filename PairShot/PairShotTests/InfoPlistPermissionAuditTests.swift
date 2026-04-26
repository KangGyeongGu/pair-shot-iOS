import Foundation
@testable import PairShot
import XCTest

/// P10.2 — `Info.plist` privacy usage description audit.
///
/// App Store review (guideline 5.1.1) rejects builds whose privacy
/// usage description strings are missing, English-only, or empty
/// boilerplate when the surrounding market is Korean. This audit
/// pins the four privacy-prompt keys we ship + ensures each carries
/// a Korean explanation long enough to convey purpose.
///
/// Running on every build means a future change to Info.plist that
/// drops a key, switches it to English placeholder, or trims it
/// below the legibility threshold breaks here, before it reaches a
/// reviewer.
final class InfoPlistPermissionAuditTests: XCTestCase {
    // MARK: - Required keys

    /// All privacy-prompt Info.plist keys the app uses at runtime.
    /// Add a key here when adding a new permission flow.
    private static let requiredKeys: [String] = [
        "NSCameraUsageDescription",
        "NSLocationWhenInUseUsageDescription",
        "NSPhotoLibraryAddUsageDescription",
        "NSUserTrackingUsageDescription",
    ]

    // MARK: - Helpers

    /// Reads the Info.plist of the host app via `Bundle.main`.
    /// Returns the raw string, or nil if the key is absent.
    ///
    /// Named `infoString(forKey:)` to avoid colliding with NSObject's
    /// KVC `value(forKey:)` which XCTestCase inherits — that collision
    /// silently routes calls to KVC and throws `NSUnknownKeyException`.
    private func infoString(forKey key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    /// Returns true if the string contains at least one Hangul
    /// syllable (U+AC00..U+D7A3) — sufficient evidence the copy is
    /// Korean rather than placeholder English.
    private func containsHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { 0xAC00 ... 0xD7A3 ~= $0.value }
    }

    // MARK: - Presence

    func testAllFourPrivacyKeysExist() {
        for key in Self.requiredKeys {
            XCTAssertNotNil(
                infoString(forKey: key),
                "Info.plist missing \(key) — runtime permission prompt would crash"
            )
        }
    }

    // MARK: - Length floor

    func testAllPrivacyDescriptionsAreAtLeastTwelveCharacters() throws {
        for key in Self.requiredKeys {
            let text = try XCTUnwrap(infoString(forKey: key))
            XCTAssertGreaterThanOrEqual(
                text.count,
                12,
                "\(key) too short (\(text.count) chars): App Store review requires meaningful purpose copy"
            )
        }
    }

    // MARK: - Korean

    func testAllPrivacyDescriptionsAreKorean() throws {
        for key in Self.requiredKeys {
            let text = try XCTUnwrap(infoString(forKey: key))
            XCTAssertTrue(
                containsHangul(text),
                "\(key) is not Korean (no Hangul syllables found): \"\(text)\""
            )
        }
    }

    // MARK: - Specific intent guards

    func testCameraDescriptionMentionsCameraOrPhoto() throws {
        let text = try XCTUnwrap(infoString(forKey: "NSCameraUsageDescription"))
        XCTAssertTrue(
            text.contains("카메라") || text.contains("사진"),
            "Camera usage copy should mention 카메라 or 사진 for clarity: \"\(text)\""
        )
    }

    func testLocationDescriptionMentionsLocation() throws {
        let text = try XCTUnwrap(infoString(forKey: "NSLocationWhenInUseUsageDescription"))
        XCTAssertTrue(
            text.contains("위치") || text.contains("현장"),
            "Location usage copy should mention 위치 or 현장: \"\(text)\""
        )
    }

    func testPhotoLibraryDescriptionMentionsLibraryOrAlbum() throws {
        let text = try XCTUnwrap(infoString(forKey: "NSPhotoLibraryAddUsageDescription"))
        let hasLibraryWord =
            text.contains("사진")
                || text.contains("앨범")
                || text.contains("라이브러리")
        XCTAssertTrue(
            hasLibraryWord,
            "Photo-library usage copy should mention 사진 / 앨범 / 라이브러리: \"\(text)\""
        )
    }

    func testTrackingDescriptionStatesGracefulDenial() throws {
        let text = try XCTUnwrap(infoString(forKey: "NSUserTrackingUsageDescription"))
        // App Store best practice: ATT prompt must explain that the
        // app keeps working when the user denies, otherwise reviewers
        // call out coercive copy.
        XCTAssertTrue(
            text.contains("거부") || text.contains("허용") || text.contains("선택"),
            "ATT copy should clarify the user's choice path: \"\(text)\""
        )
    }
}
