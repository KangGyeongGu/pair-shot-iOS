import Foundation
@testable import PairShot
import XCTest

/// P10b — static line-count audit for the 5 view files diet'd in this
/// phase. Phase 9 reviewer flagged each as exceeding the 250-line cap
/// (`.claude/refs/swiftui-patterns.md`). Locking the cap down with a
/// test prevents accidental re-bloat — anyone adding 30 lines back to
/// `ComparisonView.swift` will see a build-time failure rather than a
/// reviewer note three weeks later.
///
/// The path-resolution strategy mirrors `DeviceChecklistAuditTests`:
/// walk up from the test bundle until we land at the repo root, then
/// resolve each Swift file relative to the project sub-tree.
final class ViewLineCountAuditTests: XCTestCase {
    /// Absolute upper bound from `.claude/refs/swiftui-patterns.md`.
    /// Bumping this requires a roadmap-level decision — it is not a
    /// per-file knob.
    private let lineCountCap = 250

    // MARK: - Helpers

    /// Walks up the test-bundle URL until a directory containing a
    /// `PairShot/PairShot/PairShotApp.swift` is found. That directory
    /// is the repo root.
    private func locateRepoRoot() -> URL? {
        var url = Bundle(for: ViewLineCountAuditTests.self).bundleURL
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

    private func lineCount(forRelativePath path: String) throws -> Int {
        guard let root = locateRepoRoot() else {
            throw XCTSkip("Repo root not located — running outside expected layout")
        }
        let fileURL = root.appendingPathComponent(path)
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        // Match `wc -l` semantics — count newline-terminated lines.
        // `split(separator: "\n", omittingEmptySubsequences: false)`
        // returns one extra empty trailing element when the file ends
        // with `\n`; subtract 1 in that case so 250-line files are
        // counted as 250 not 251.
        let parts = contents.split(separator: "\n", omittingEmptySubsequences: false)
        let trailingNewline = contents.hasSuffix("\n") ? 1 : 0
        return parts.count - trailingNewline
    }

    private func assertUnderCap(_ relativePath: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let count = try lineCount(forRelativePath: relativePath)
        XCTAssertLessThanOrEqual(
            count,
            lineCountCap,
            "\(relativePath) is \(count) lines (cap = \(lineCountCap)) — extract a subview",
            file: file,
            line: line
        )
    }

    // MARK: - per-file caps (P10b diet)

    func testBeforeCameraViewUnderCap() throws {
        try assertUnderCap("PairShot/PairShot/Features/CameraBefore/BeforeCameraView.swift")
    }

    func testAfterCameraViewUnderCap() throws {
        try assertUnderCap("PairShot/PairShot/Features/CameraAfter/AfterCameraView.swift")
    }

    func testComparisonViewUnderCap() throws {
        try assertUnderCap("PairShot/PairShot/Features/Comparison/ComparisonView.swift")
    }

    func testCouponRegistrationViewUnderCap() throws {
        try assertUnderCap("PairShot/PairShot/Features/Settings/CouponRegistrationView.swift")
    }

    func testQRScannerViewUnderCap() throws {
        try assertUnderCap("PairShot/PairShot/Features/Settings/QRScannerView.swift")
    }

    // MARK: - sanity: extracted subview files exist

    func testExtractedSubviewFilesExist() throws {
        guard let root = locateRepoRoot() else {
            throw XCTSkip("Repo root not located")
        }
        let extractedFiles = [
            "PairShot/PairShot/Features/CameraBefore/CameraStack.swift",
            "PairShot/PairShot/Features/CameraAfter/AfterCameraStack.swift",
            "PairShot/PairShot/Features/Comparison/CompositeMenu.swift",
            "PairShot/PairShot/Features/Settings/CouponRegistrationSections.swift",
            "PairShot/PairShot/Features/Settings/QRScannerViewController.swift",
        ]
        for relativePath in extractedFiles {
            let url = root.appendingPathComponent(relativePath)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "extracted subview file missing: \(relativePath)"
            )
        }
    }
}
