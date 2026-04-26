import Foundation
@testable import PairShot
import UIKit
import XCTest

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

    @discardableResult
    private func writeSampleJPEG(color: UIColor = .red) throws -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        let fileName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        return try storage.saveBeforeJPEG(data, fileName: fileName)
    }

    func testLoadThumbnailDecodesAndReturnsImage() throws {
        let name = try writeSampleJPEG()
        let image = cache.loadThumbnail(kind: .before, fileName: name, storage: storage, pixelSize: 64)
        let unwrapped = try XCTUnwrap(image)
        XCTAssertGreaterThan(unwrapped.size.width, 0)
        XCTAssertGreaterThan(unwrapped.size.height, 0)
    }

    func testRepeatedLoadHitsCacheNotDisk() throws {
        let name = try writeSampleJPEG()
        let first = try XCTUnwrap(cache.loadThumbnail(kind: .before, fileName: name, storage: storage))

        let absolute = try XCTUnwrap(storage.resolve(kind: .before, fileName: name))
        try FileManager.default.removeItem(at: absolute)
        // Also remove the disk thumbnail so a hit really is from memory.
        let thumbName = FileNameBuilder.thumbnail(forBaseName: name)
        if let thumbURL = storage.resolveThumbnail(kind: .before, fileName: thumbName) {
            try? FileManager.default.removeItem(at: thumbURL)
        }

        let second = cache.loadThumbnail(kind: .before, fileName: name, storage: storage)
        XCTAssertNotNil(second)
        XCTAssertTrue(first === second, "cache must return identical UIImage instance")
    }

    func testCachedReturnsNilBeforeFirstLoad() throws {
        let name = try writeSampleJPEG()
        XCTAssertNil(cache.cached(kind: .before, fileName: name))
        _ = cache.loadThumbnail(kind: .before, fileName: name, storage: storage)
        XCTAssertNotNil(cache.cached(kind: .before, fileName: name))
    }

    func testEvictRemovesSpecificEntry() throws {
        let nameA = try writeSampleJPEG(color: .red)
        let nameB = try writeSampleJPEG(color: .blue)

        _ = cache.loadThumbnail(kind: .before, fileName: nameA, storage: storage)
        _ = cache.loadThumbnail(kind: .before, fileName: nameB, storage: storage)
        XCTAssertNotNil(cache.cached(kind: .before, fileName: nameA))
        XCTAssertNotNil(cache.cached(kind: .before, fileName: nameB))

        cache.evict(beforeFileName: nameA)
        XCTAssertNil(cache.cached(kind: .before, fileName: nameA))
        XCTAssertNotNil(cache.cached(kind: .before, fileName: nameB))
    }

    func testLoadThumbnailWithEmptyPathReturnsNil() {
        XCTAssertNil(cache.loadThumbnail(kind: .before, fileName: "", storage: storage))
    }

    func testLoadThumbnailWithMissingFileReturnsNil() {
        let bogus = "missing-\(UUID().uuidString).jpg"
        XCTAssertNil(cache.loadThumbnail(kind: .before, fileName: bogus, storage: storage))
    }

    func testRemoveAllClearsCache() throws {
        let name = try writeSampleJPEG()
        _ = cache.loadThumbnail(kind: .before, fileName: name, storage: storage)
        XCTAssertNotNil(cache.cached(kind: .before, fileName: name))
        cache.removeAll()
        XCTAssertNil(cache.cached(kind: .before, fileName: name))
    }

    func testDownsampleRespectsPixelSizeBudget() throws {
        let name = try writeSampleJPEG()
        let url = try XCTUnwrap(storage.resolve(kind: .before, fileName: name))
        let small = try XCTUnwrap(ThumbnailCache.downsample(at: url, pixelSize: 32))
        let longEdge = max(small.size.width, small.size.height) * small.scale
        XCTAssertLessThanOrEqual(longEdge, 64)
    }

    func testEstimatedByteCostIsPositiveForRealImages() throws {
        let name = try writeSampleJPEG()
        let image = try XCTUnwrap(cache.loadThumbnail(kind: .before, fileName: name, storage: storage))
        XCTAssertGreaterThan(ThumbnailCache.estimatedByteCost(image), 0)
    }

    deinit {}
}
