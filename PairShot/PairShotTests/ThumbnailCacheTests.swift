@testable import PairShot
import Testing
import UIKit

@MainActor
struct ThumbnailCacheTests {
    private func makeTempJpegPath() throws -> String {
        let tmpDir = FileManager.default.temporaryDirectory
        let path = tmpDir.appendingPathComponent(UUID().uuidString + ".jpg").path
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        guard let data = image.jpegData(compressionQuality: 0.5) else {
            struct JpegEncodeError: Error {}
            throw JpegEncodeError()
        }
        try data.write(to: URL(fileURLWithPath: path))
        return path
    }

    // MARK: - image(for:) happy path

    @Test func image_happyPath_cacheMissLoadFromFileAndReturnNonNil() throws {
        let cache = ThumbnailCache.shared
        cache.removeAll()

        let path = try makeTempJpegPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = cache.image(for: path)

        #expect(result != nil)
    }

    @Test func image_happyPath_cachedImageIsSameInstanceOnSecondCall() throws {
        let cache = ThumbnailCache.shared
        cache.removeAll()

        let path = try makeTempJpegPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let first = cache.image(for: path)
        let second = cache.image(for: path)

        #expect(first === second)
    }

    // MARK: - image(for:) boundary

    @Test func image_boundary_samePathAfterRemoveAllReturnsNonNilFromFile() throws {
        let cache = ThumbnailCache.shared
        cache.removeAll()

        let path = try makeTempJpegPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        _ = cache.image(for: path)
        cache.removeAll()

        let result = cache.image(for: path)
        #expect(result != nil)
    }

    @Test func image_boundary_twoDistinctPathsReturnIndependentImages() throws {
        let cache = ThumbnailCache.shared
        cache.removeAll()

        let path1 = try makeTempJpegPath()
        let path2 = try makeTempJpegPath()
        defer {
            try? FileManager.default.removeItem(atPath: path1)
            try? FileManager.default.removeItem(atPath: path2)
        }

        let img1 = cache.image(for: path1)
        let img2 = cache.image(for: path2)

        #expect(img1 != nil)
        #expect(img2 != nil)
        #expect(img1 !== img2)
    }

    // MARK: - image(for:) negative

    @Test func image_negative_missingFilePathReturnsNil() {
        let cache = ThumbnailCache.shared
        cache.removeAll()

        let nonExistentPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".jpg").path

        let result = cache.image(for: nonExistentPath)

        #expect(result == nil)
    }

    @Test func image_negative_emptyStringPathReturnsNil() {
        let cache = ThumbnailCache.shared
        cache.removeAll()

        let result = cache.image(for: "")

        #expect(result == nil)
    }

    // MARK: - image(for:) error

    @Test func image_error_deletedFileAfterCacheStillReturnsCachedImage() throws {
        let cache = ThumbnailCache.shared
        cache.removeAll()

        let path = try makeTempJpegPath()

        let first = cache.image(for: path)
        #expect(first != nil)

        try FileManager.default.removeItem(atPath: path)

        let second = cache.image(for: path)
        #expect(second != nil)
        #expect(first === second)
    }
}
