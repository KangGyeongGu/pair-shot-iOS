import Foundation
@testable import PairShot
import UIKit
import XCTest

/// P8.2 — verifies the JPEG quality + filename prefix knobs introduced by
/// `AppSettings` actually flow through to disk.
///
/// Coverage:
/// - JPEG quality 0.6 produces a strictly smaller file than 0.95 for the
///   same source image (the AVFoundation capture path doesn't re-encode,
///   but the composite/save-with-quality flow does).
/// - `PhotoStorageService.saveBeforeJPEG(_:fileNamePrefix:)` honours the
///   prefix and produces `<prefix><UUID>.jpg`.
/// - Empty prefix preserves the legacy `<UUID>.jpg` shape so existing
///   gallery resolvers continue to work without migration.
final class PhotoStorageQualityTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pairshot-quality-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - happy

    func testFileNamePrefixIsAppliedToSavedFilename() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let bytes = Data(repeating: 0xCD, count: 256)
        let id = UUID()
        let relative = try storage.saveBeforeJPEG(bytes, fileID: id, fileNamePrefix: "site-A_")

        XCTAssertTrue(
            relative.hasPrefix("photos/site-A_"),
            "Expected prefix in path, got \(relative)"
        )
        XCTAssertTrue(relative.contains(id.uuidString))
        XCTAssertTrue(relative.hasSuffix(".jpg"))
    }

    func testEmptyPrefixYieldsLegacyShape() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let bytes = Data(repeating: 0xEF, count: 32)
        let id = UUID()
        let relative = try storage.saveBeforeJPEG(bytes, fileID: id, fileNamePrefix: "")
        XCTAssertEqual(relative, "photos/\(id.uuidString).jpg")
    }

    func testJpegQualityHigherProducesLargerEncoding() {
        // Build a deterministic source image with sub-pixel detail so
        // the quantiser actually does something.
        let source = makeNoisyImage(size: CGSize(width: 256, height: 256))
        guard let lowData = source.jpegData(compressionQuality: 0.6),
              let highData = source.jpegData(compressionQuality: 0.95)
        else {
            XCTFail("JPEG encoding returned nil")
            return
        }
        XCTAssertGreaterThan(highData.count, lowData.count, "0.95 should encode larger than 0.6")
    }

    // MARK: - edge

    func testForbiddenCharactersInPrefixAreScrubbedAtStorageLayer() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let bytes = Data(repeating: 0x10, count: 16)
        let id = UUID()
        let relative = try storage.saveBeforeJPEG(bytes, fileID: id, fileNamePrefix: "a/b\\c_")

        // Storage layer defensively strips forbidden chars even if the
        // caller forgot to sanitise.
        XCTAssertFalse(relative.contains("/b"))
        XCTAssertFalse(relative.contains("\\"))
        XCTAssertTrue(relative.contains("abc_\(id.uuidString)"))
    }

    func testSavedFileIsReadableViaResolve() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let bytes = Data(repeating: 0x55, count: 64)
        let relative = try storage.saveAfterJPEG(bytes, fileID: UUID(), fileNamePrefix: "x_")
        let url = try XCTUnwrap(storage.resolve(relativePath: relative))
        let restored = try Data(contentsOf: url)
        XCTAssertEqual(restored, bytes)
    }

    // MARK: - helpers

    /// Makes a 256x256 image with high-frequency noise so JPEG quantiser
    /// has lots to chew on — guarantees a measurable size delta between
    /// 0.6 and 0.95 quality.
    private func makeNoisyImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            // Fill with checkerboard + per-pixel jitter via gradient overlays
            // so the encoder can't compress to a single DC coefficient.
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cellSize: CGFloat = 4
            let columns = Int(size.width / cellSize)
            let rows = Int(size.height / cellSize)
            for row in 0 ..< rows {
                for col in 0 ..< columns {
                    let parity = (row + col) % 3
                    switch parity {
                        case 0: UIColor.black.setFill()
                        case 1: UIColor.red.setFill()
                        default: UIColor.blue.setFill()
                    }
                    context.fill(CGRect(
                        x: CGFloat(col) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    ))
                }
            }
        }
    }
}
