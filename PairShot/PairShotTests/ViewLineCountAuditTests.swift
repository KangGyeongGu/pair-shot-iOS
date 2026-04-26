import Foundation
@testable import PairShot
import XCTest

/// P10b — static line-count audit for the view files diet'd in this
/// phase. Phase 9 reviewer flagged each as exceeding the 250-line cap
/// (`.claude/refs/swiftui-patterns.md`). Locking the cap down with a
/// test prevents accidental re-bloat — anyone adding 30 lines back to
/// `ComparisonView.swift` will see a build-time failure rather than a
/// reviewer note three weeks later.
///
/// **Audit-D** — repo-root resolution moved to ``TestRepoLocator`` so
/// the test runs on Simulator (previously `XCTSkip`'d). New diet'd files
/// (`ArchiveView`, `PairGalleryView`, `ShareSheet`) are added to the
/// audit alongside the P10b set.
final class ViewLineCountAuditTests: XCTestCase {
    /// Absolute upper bound from `.claude/refs/swiftui-patterns.md`.
    /// Bumping this requires a roadmap-level decision — it is not a
    /// per-file knob.
    private let lineCountCap = 250

    // MARK: - Helpers

    private func lineCount(forRelativePath path: String) throws -> Int {
        let root = try XCTUnwrap(
            TestRepoLocator.repoRoot,
            "TestRepoLocator failed to derive repo root from #filePath — Audit-D regression"
        )
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

    private func assertUnderCap(
        _ relativePath: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
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

    // MARK: - per-file caps (Audit-D diet)

    func testPairGalleryViewUnderCap() throws {
        try assertUnderCap("PairShot/PairShot/Features/Gallery/PairGalleryView.swift")
    }

    func testShareSheetUnderCap() throws {
        try assertUnderCap("PairShot/PairShot/Features/Export/ShareSheet.swift")
    }

    func testExportPickerUnderCap() throws {
        try assertUnderCap("PairShot/PairShot/Features/Export/ExportPicker.swift")
    }

    // MARK: - sanity: extracted subview files exist

    func testExtractedSubviewFilesExist() throws {
        let root = try XCTUnwrap(TestRepoLocator.repoRoot)
        let extractedFiles = [
            // P10b extractions
            "PairShot/PairShot/Features/CameraBefore/CameraStack.swift",
            "PairShot/PairShot/Features/CameraAfter/AfterCameraStack.swift",
            "PairShot/PairShot/Features/Comparison/CompositeMenu.swift",
            "PairShot/PairShot/Features/Settings/CouponRegistrationSections.swift",
            "PairShot/PairShot/Features/Settings/QRScannerViewController.swift",
            // Audit-D extractions
            "PairShot/PairShot/Features/Gallery/PairGallery+Cameras.swift",
            "PairShot/PairShot/Features/Export/ExportPicker.swift",
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
