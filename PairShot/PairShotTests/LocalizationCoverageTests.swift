import Foundation
@testable import PairShot
import XCTest

/// Audit-C — guard against accidental Korean string literals reappearing
/// in user-facing surfaces after the audit centralised every label
/// through `String(localized:)`.
///
/// The check is grep-based: read each Swift file, strip comments, then
/// fail if any non-comment line contains a Korean Hangul scalar
/// outside an allow-listed wrapper (`String(localized:`,
/// `LocalizedStringKey`, `// MARK:`, etc.).
///
/// This catches the most common regression — a contributor adding
/// `Text("새 항목")` instead of `Text(String(localized: "새 항목"))` —
/// without trying to fully parse Swift.
///
/// **Audit-D** — repo-root resolution moved to ``TestRepoLocator`` so
/// the test runs on Simulator (previously `XCTSkip`'d because the walk
/// up from `Bundle.bundleURL` never reached the actual repo root).
final class LocalizationCoverageTests: XCTestCase {
    private let scannedFiles: [String] = [
        "PairShot/PairShot/Features/Gallery/PairGalleryView.swift",
        "PairShot/PairShot/Features/Gallery/MultiSelectBar.swift",
        "PairShot/PairShot/Features/Gallery/PairGallery+Cameras.swift",
        "PairShot/PairShot/Features/Gallery/GalleryFilter.swift",
        "PairShot/PairShot/Features/Gallery/PairThumbnailCell.swift",
    ]

    /// True when the line contains at least one Hangul syllable.
    private func containsHangul(_ line: String) -> Bool {
        line.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7AF }
    }

    /// True when the line is either a comment or routes the Korean
    /// through `String(localized:)` / `LocalizedStringKey`. Approximate
    /// — we strip everything inside double-quoted string literals that
    /// follow `String(localized:` so the remainder still gets checked.
    private func isLocalizedOrComment(_ rawLine: String) -> Bool {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*") {
            return true
        }
        // Strip out `String(localized: "...")` payloads.
        var sanitised = rawLine
        while let range = sanitised.range(
            of: #"String\(localized:\s*"[^"]*"\)"#,
            options: .regularExpression
        ) {
            sanitised.replaceSubrange(range, with: "")
        }
        // Strip out `LocalizedStringKey("...")`.
        while let range = sanitised.range(
            of: #"LocalizedStringKey\("[^"]*"\)"#,
            options: .regularExpression
        ) {
            sanitised.replaceSubrange(range, with: "")
        }
        return !containsHangul(sanitised)
    }

    func testGallerySurfaceFilesDoNotContainBareKoreanLiterals() throws {
        let root = try XCTUnwrap(
            TestRepoLocator.repoRoot,
            "TestRepoLocator failed to derive repo root from #filePath — Audit-D regression"
        )

        var offences: [String] = []
        for relativePath in scannedFiles {
            let url = root.appendingPathComponent(relativePath)
            let contents = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in contents.split(
                separator: "\n", omittingEmptySubsequences: false
            ).enumerated() {
                let lineString = String(line)
                guard containsHangul(lineString) else { continue }
                if isLocalizedOrComment(lineString) { continue }
                offences.append(
                    "\(relativePath):\(index + 1): \(lineString.trimmingCharacters(in: .whitespaces))"
                )
            }
        }

        XCTAssertTrue(
            offences.isEmpty,
            "bare Korean literals must route through String(localized:):\n"
                + offences.joined(separator: "\n")
        )
    }

    func testWatermarkOverlayDoesNotHardcodeKoreanLocale() throws {
        let root = try XCTUnwrap(TestRepoLocator.repoRoot)
        let url = root.appendingPathComponent("PairShot/PairShot/Services/WatermarkOverlay.swift")
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(
            contents.contains(#"Locale(identifier: "ko_KR")"#),
            "Audit-C — WatermarkOverlay must not hardcode Locale(identifier: \"ko_KR\"); use Locale.current"
        )
    }

    func testAdFreeStatusFormatterUsesPosixLocale() throws {
        let root = try XCTUnwrap(TestRepoLocator.repoRoot)
        let url = root.appendingPathComponent(
            "PairShot/PairShot/Features/Settings/AdFreeStatusView.swift"
        )
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            contents.contains(#"Locale(identifier: "en_US_POSIX")"#),
            "Audit-C — AdFreeStatusFormatter.formatDate must pin DateFormatter to en_US_POSIX"
        )
    }
}
