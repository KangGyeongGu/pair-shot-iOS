import Foundation
@testable import PairShot
import XCTest

/// P9.3 — `Localizable.strings` parity audit.
///
/// Verifies the ko/en `.strings` files share the same key set so a
/// translation drift (key added to ko but not en, or vice versa)
/// surfaces here rather than as a runtime "key returned as-is"
/// regression on an English-locale device.
///
/// We read the raw `.strings` files from the test bundle's resource
/// search path — `Bundle(for: type(of: self))` is the test bundle,
/// not the app, so we walk up to `Bundle.main` to find the lproj
/// directories the app target ships.
final class LocalizableKeysAuditTests: XCTestCase {
    // MARK: - Helpers

    /// Loads keys from the app bundle's `<lang>.lproj/Localizable.strings`.
    /// Returns `nil` when the file is missing — the tests below treat
    /// that as a hard failure rather than skipping silently.
    private func loadKeys(language: String) -> Set<String>? {
        guard
            let path = Bundle.main.path(
                forResource: "Localizable",
                ofType: "strings",
                inDirectory: nil,
                forLocalization: language
            ),
            let dict = NSDictionary(contentsOfFile: path) as? [String: String]
        else {
            return nil
        }
        return Set(dict.keys)
    }

    // MARK: - Parity

    func testKoreanKeysExist() throws {
        let keys = try XCTUnwrap(
            loadKeys(language: "ko"),
            "ko.lproj/Localizable.strings missing or unreadable"
        )
        XCTAssertGreaterThan(
            keys.count,
            50,
            "expected at least 50 ko strings — phase scope says ~120"
        )
    }

    func testEnglishKeysExist() throws {
        let keys = try XCTUnwrap(
            loadKeys(language: "en"),
            "en.lproj/Localizable.strings missing or unreadable"
        )
        XCTAssertGreaterThan(
            keys.count,
            50,
            "expected at least 50 en strings — phase scope says ~120"
        )
    }

    func testKoreanAndEnglishKeysAreIdentical() throws {
        let ko = try XCTUnwrap(loadKeys(language: "ko"))
        let en = try XCTUnwrap(loadKeys(language: "en"))

        let onlyInKo = ko.subtracting(en).sorted()
        let onlyInEn = en.subtracting(ko).sorted()

        XCTAssertTrue(
            onlyInKo.isEmpty,
            "keys present only in ko: \(onlyInKo)"
        )
        XCTAssertTrue(
            onlyInEn.isEmpty,
            "keys present only in en: \(onlyInEn)"
        )
    }
}
