import Foundation
@testable import PairShot
import XCTest

/// Audit-C — guard against accidental Korean string literals reappearing
/// in `Features/Archive/` after the audit centralised every label
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
final class LocalizationCoverageTests: XCTestCase {
    private let scannedFiles: [String] = [
        "PairShot/PairShot/Features/Archive/ArchiveView.swift",
        "PairShot/PairShot/Features/Archive/ArchiveView+Edit.swift",
        "PairShot/PairShot/Features/Archive/ArchiveView+MultiSelect.swift",
        "PairShot/PairShot/Features/Archive/NewProjectSheet.swift",
    ]

    /// Same path-walk used by `ViewLineCountAuditTests`.
    private func locateRepoRoot() -> URL? {
        var url = Bundle(for: LocalizationCoverageTests.self).bundleURL
        for _ in 0 ..< 8 {
            url = url.deletingLastPathComponent()
            let probe = url
                .appendingPathComponent("PairShot")
                .appendingPathComponent("PairShot")
                .appendingPathComponent("PairShotApp.swift")
            if FileManager.default.fileExists(atPath: probe.path) {
                return url
            }
        }
        return nil
    }

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

    func testArchiveSurfaceFilesDoNotContainBareKoreanLiterals() throws {
        guard let root = locateRepoRoot() else {
            throw XCTSkip("repo root not located — running outside expected layout")
        }

        var offences: [String] = []
        for relativePath in scannedFiles {
            let url = root.appendingPathComponent(relativePath)
            let contents = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let lineString = String(line)
                guard containsHangul(lineString) else { continue }
                if isLocalizedOrComment(lineString) { continue }
                offences.append("\(relativePath):\(index + 1): \(lineString.trimmingCharacters(in: .whitespaces))")
            }
        }

        XCTAssertTrue(
            offences.isEmpty,
            "bare Korean literals must route through String(localized:):\n" + offences.joined(separator: "\n")
        )
    }

    func testWatermarkOverlayDoesNotHardcodeKoreanLocale() throws {
        guard let root = locateRepoRoot() else {
            throw XCTSkip("repo root not located")
        }
        let url = root.appendingPathComponent("PairShot/PairShot/Services/WatermarkOverlay.swift")
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(
            contents.contains(#"Locale(identifier: "ko_KR")"#),
            "Audit-C — WatermarkOverlay must not hardcode Locale(identifier: \"ko_KR\"); use Locale.current"
        )
    }

    func testAdFreeStatusFormatterUsesPosixLocale() throws {
        guard let root = locateRepoRoot() else {
            throw XCTSkip("repo root not located")
        }
        let url = root.appendingPathComponent("PairShot/PairShot/Features/Settings/AdFreeStatusView.swift")
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            contents.contains(#"Locale(identifier: "en_US_POSIX")"#),
            "Audit-C — AdFreeStatusFormatter.formatDate must pin DateFormatter to en_US_POSIX"
        )
    }
}
