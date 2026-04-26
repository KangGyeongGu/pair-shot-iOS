import Foundation
@testable import PairShot
import UIKit
import XCTest

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

    func testFileNameBuilderAppliesPrefix() {
        let id = UUID()
        let name = FileNameBuilder.before(
            prefix: "site-A",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            pairId: id
        )
        XCTAssertTrue(name.hasPrefix("site-A_before_"))
        XCTAssertTrue(name.hasSuffix(".jpg"))
        XCTAssertTrue(name.contains(FileNameBuilder.shortId(from: id)))
    }

    func testFileNameBuilderEmptyPrefixOmitsLeadingUnderscore() {
        let id = UUID()
        let name = FileNameBuilder.before(
            prefix: "",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            pairId: id
        )
        XCTAssertTrue(name.hasPrefix("before_"))
    }

    func testJpegQualityHigherProducesLargerEncoding() {
        let source = makeNoisyImage(size: CGSize(width: 256, height: 256))
        guard let lowData = source.jpegData(compressionQuality: 0.6),
              let highData = source.jpegData(compressionQuality: 0.95)
        else {
            XCTFail("JPEG encoding returned nil")
            return
        }
        XCTAssertGreaterThan(highData.count, lowData.count, "0.95 should encode larger than 0.6")
    }

    func testForbiddenCharactersInPrefixAreScrubbed() {
        let id = UUID()
        let name = FileNameBuilder.before(
            prefix: "a/b\\c",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            pairId: id
        )
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains("\\"))
        XCTAssertTrue(name.hasPrefix("abc_before_"))
    }

    func testSavedFileIsReadableViaResolve() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let bytes = Data(repeating: 0x55, count: 64)
        let id = UUID()
        let name = FileNameBuilder.after(prefix: "x", timestamp: .now, pairId: id)
        let returned = try storage.saveAfterJPEG(bytes, fileName: name)
        let url = try XCTUnwrap(storage.resolve(kind: .after, fileName: returned))
        let restored = try Data(contentsOf: url)
        XCTAssertEqual(restored, bytes)
    }

    private func makeNoisyImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
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

    deinit {}
}
