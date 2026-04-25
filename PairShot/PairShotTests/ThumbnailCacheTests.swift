import Foundation
@testable import PairShot
import UIKit
import XCTest

/// P4.4 — `ThumbnailCache` decode + memory cache + eviction.
final class ThumbnailCacheTests: XCTestCase {
    private var tempDir: URL!
    private var storage: PhotoStorageService!
    private var cache: ThumbnailCache!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pairshot-thumb-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = PhotoStorageService(baseDirectory: tempDir)
        cache = ThumbnailCache()
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        cache.removeAll()
        cache = nil
        storage = nil
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// Encode a 100×100 solid-colour `UIImage` to JPEG and write through the
    /// `PhotoStorageService` so we can exercise the real decode path.
    @discardableResult
    private func writeSampleJPEG(color: UIColor = .red) throws -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        return try storage.saveBeforeJPEG(data)
    }

    // MARK: - happy

    func testLoadThumbnailDecodesAndReturnsImage() throws {
        let path = try writeSampleJPEG()
        let image = cache.loadThumbnail(forRelativePath: path, storage: storage, pixelSize: 64)
        let unwrapped = try XCTUnwrap(image)
        XCTAssertGreaterThan(unwrapped.size.width, 0)
        XCTAssertGreaterThan(unwrapped.size.height, 0)
    }

    func testRepeatedLoadHitsCacheNotDisk() throws {
        let path = try writeSampleJPEG()
        let first = try XCTUnwrap(cache.loadThumbnail(forRelativePath: path, storage: storage))

        // Delete file from disk; if the second load decodes again it would
        // return nil. Cache must short-circuit.
        let absolute = try XCTUnwrap(storage.resolve(relativePath: path))
        try FileManager.default.removeItem(at: absolute)

        let second = cache.loadThumbnail(forRelativePath: path, storage: storage)
        XCTAssertNotNil(second)
        XCTAssertTrue(first === second, "cache must return identical UIImage instance")
    }

    func testCachedReturnsNilBeforeFirstLoad() throws {
        let path = try writeSampleJPEG()
        XCTAssertNil(cache.cached(forRelativePath: path))
        _ = cache.loadThumbnail(forRelativePath: path, storage: storage)
        XCTAssertNotNil(cache.cached(forRelativePath: path))
    }

    func testEvictRemovesSpecificEntry() throws {
        let pathA = try writeSampleJPEG(color: .red)
        let pathB = try writeSampleJPEG(color: .blue)

        _ = cache.loadThumbnail(forRelativePath: pathA, storage: storage)
        _ = cache.loadThumbnail(forRelativePath: pathB, storage: storage)
        XCTAssertNotNil(cache.cached(forRelativePath: pathA))
        XCTAssertNotNil(cache.cached(forRelativePath: pathB))

        cache.evict(relativePath: pathA)
        XCTAssertNil(cache.cached(forRelativePath: pathA))
        XCTAssertNotNil(cache.cached(forRelativePath: pathB))
    }

    // MARK: - edge

    func testLoadThumbnailWithEmptyPathReturnsNil() {
        XCTAssertNil(cache.loadThumbnail(forRelativePath: "", storage: storage))
    }

    func testLoadThumbnailWithMissingFileReturnsNil() {
        let bogus = "photos/does-not-exist-\(UUID().uuidString).jpg"
        XCTAssertNil(cache.loadThumbnail(forRelativePath: bogus, storage: storage))
    }

    func testRemoveAllClearsCache() throws {
        let path = try writeSampleJPEG()
        _ = cache.loadThumbnail(forRelativePath: path, storage: storage)
        XCTAssertNotNil(cache.cached(forRelativePath: path))
        cache.removeAll()
        XCTAssertNil(cache.cached(forRelativePath: path))
    }

    func testDownsampleRespectsPixelSizeBudget() throws {
        let path = try writeSampleJPEG()
        let url = try XCTUnwrap(storage.resolve(relativePath: path))
        let small = try XCTUnwrap(ThumbnailCache.downsample(at: url, pixelSize: 32))
        // Long edge should be roughly capped by the requested budget.
        let longEdge = max(small.size.width, small.size.height) * small.scale
        XCTAssertLessThanOrEqual(longEdge, 64) // small headroom for ImageIO rounding
    }

    func testEstimatedByteCostIsPositiveForRealImages() throws {
        let path = try writeSampleJPEG()
        let image = try XCTUnwrap(cache.loadThumbnail(forRelativePath: path, storage: storage))
        XCTAssertGreaterThan(ThumbnailCache.estimatedByteCost(image), 0)
    }
}
