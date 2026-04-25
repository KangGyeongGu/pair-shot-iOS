import Foundation
@testable import PairShot
import UIKit
import XCTest

/// P3.2 — Before semi-transparent overlay + alpha slider.
///
/// We test the math + loader; the SwiftUI view itself is rendered visually
/// in `#Preview` (not a test target).
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

    // MARK: - clamp (math)

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

    // MARK: - loader (file-system)

    func testLoadImageReturnsUIImageForExistingFile() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)

        // Generate a tiny JPEG via a 1×1 UIImage so UIImage(contentsOfFile:)
        // can decode it on the simulator.
        let image = makePixelImage(color: .red)
        let jpegData = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        let relative = try storage.saveBeforeJPEG(jpegData)

        let loaded = GhostOverlayLoader.loadImage(relativePath: relative, storage: storage)
        XCTAssertNotNil(loaded, "Loader should decode a JPEG written by PhotoStorageService")
    }

    func testLoadImageReturnsNilForBlankPath() {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        XCTAssertNil(GhostOverlayLoader.loadImage(relativePath: "", storage: storage))
    }

    func testLoadImageReturnsNilForMissingFile() {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        XCTAssertNil(GhostOverlayLoader.loadImage(
            relativePath: "photos/does-not-exist.jpg",
            storage: storage
        ))
    }

    // MARK: - helpers

    private func makePixelImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    deinit {}
}
