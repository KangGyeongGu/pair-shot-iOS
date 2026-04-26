import Foundation
@testable import PairShot
import UIKit
import XCTest

final class GhostOverlayTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ghost-overlay-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    func testClampPassesThroughInRangeValues() {
        XCTAssertEqual(GhostOverlayMath.clamp(0.0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(GhostOverlayMath.clamp(0.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(GhostOverlayMath.clamp(1.0), 1.0, accuracy: 1e-9)
    }

    func testClampSnapsBelowZeroToZero() {
        XCTAssertEqual(GhostOverlayMath.clamp(-0.3), 0.0, accuracy: 1e-9)
        XCTAssertEqual(GhostOverlayMath.clamp(-99.0), 0.0, accuracy: 1e-9)
    }

    func testClampSnapsAboveOneToOne() {
        XCTAssertEqual(GhostOverlayMath.clamp(1.4), 1.0, accuracy: 1e-9)
        XCTAssertEqual(GhostOverlayMath.clamp(99.0), 1.0, accuracy: 1e-9)
    }

    func testDefaultAlphaIsHalfAndInRange() {
        XCTAssertEqual(GhostOverlayMath.defaultAlpha, 0.5, accuracy: 1e-9)
        XCTAssertTrue(GhostOverlayMath.alphaRange.contains(GhostOverlayMath.defaultAlpha))
    }

    func testLoadImageReturnsUIImageForExistingFile() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)

        let image = makePixelImage(color: .red)
        let jpegData = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        let fileName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(jpegData, fileName: fileName)

        let loaded = GhostOverlayLoader.loadImage(beforeFileName: fileName, storage: storage)
        XCTAssertNotNil(loaded, "Loader should decode a JPEG written by PhotoStorageService")
    }

    func testLoadImageReturnsNilForBlankFileName() {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        XCTAssertNil(GhostOverlayLoader.loadImage(beforeFileName: "", storage: storage))
    }

    func testLoadImageReturnsNilForMissingFile() {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        XCTAssertNil(GhostOverlayLoader.loadImage(
            beforeFileName: "does-not-exist.jpg",
            storage: storage
        ))
    }

    private func makePixelImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    deinit {}
}
