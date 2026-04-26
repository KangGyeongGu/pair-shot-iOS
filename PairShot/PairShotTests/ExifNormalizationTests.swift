import Foundation
import ImageIO
@testable import PairShot
import UIKit
import XCTest

final class ExifNormalizationTests: XCTestCase {
    func testNormalizeReturnsInputForUprightImage() {
        let upright = makeJPEG(orientation: .up, color: .red)
        let normalized = ExifNormalizer.normalize(upright)
        let outOrientation = readOrientation(normalized)
        XCTAssertEqual(outOrientation, 1, "upright must remain orientation = 1")
    }

    func testNormalizeFlipsRotated180Image() {
        let rotated = makeJPEG(orientation: .down, color: .blue)
        let normalized = ExifNormalizer.normalize(rotated)
        XCTAssertEqual(readOrientation(normalized), 1)
    }

    func testNormalizeFlipsRotatedRightImage() {
        let rotated = makeJPEG(orientation: .right, color: .green)
        let normalized = ExifNormalizer.normalize(rotated)
        XCTAssertEqual(readOrientation(normalized), 1)
    }

    func testNormalizeFlipsRotatedLeftImage() {
        let rotated = makeJPEG(orientation: .left, color: .yellow)
        let normalized = ExifNormalizer.normalize(rotated)
        XCTAssertEqual(readOrientation(normalized), 1)
    }

    func testNormalizeReturnsInputForNonImageData() {
        let bogus = Data([0x00, 0x01, 0x02])
        let normalized = ExifNormalizer.normalize(bogus)
        XCTAssertEqual(normalized, bogus, "non-image input must passthrough untouched")
    }

    private func makeJPEG(orientation: UIImage.Orientation, color: UIColor) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16), format: format)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        let oriented = UIImage(cgImage: image.cgImage!, scale: 1, orientation: orientation)
        return oriented.jpegData(compressionQuality: 0.9) ?? Data()
    }

    private func readOrientation(_ data: Data) -> Int? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [String: Any] else { return nil }
        return props[kCGImagePropertyOrientation as String] as? Int
    }

    deinit {}
}
