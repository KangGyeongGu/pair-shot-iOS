import Foundation
@testable import PairShot
import XCTest

final class PhotoStorageDirectoryMigrationTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("photo-storage-dir-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    func testPhotosDirectorySplitsByKind() {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let beforeDir = storage.photosDirectory(for: .before)
        let afterDir = storage.photosDirectory(for: .after)
        let combinedDir = storage.photosDirectory(for: .combined)

        XCTAssertTrue(beforeDir.path.hasSuffix("photos/before"))
        XCTAssertTrue(afterDir.path.hasSuffix("photos/after"))
        XCTAssertTrue(combinedDir.path.hasSuffix("photos/combined"))
    }

    func testThumbnailsDirectorySplitsByKind() {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        XCTAssertTrue(storage.thumbnailsDirectory(for: .before).path.hasSuffix("thumbnails/before"))
        XCTAssertTrue(storage.thumbnailsDirectory(for: .after).path.hasSuffix("thumbnails/after"))
        XCTAssertTrue(storage.thumbnailsDirectory(for: .combined).path.hasSuffix("thumbnails/combined"))
    }

    func testSavingCreatesKindDirectoryEagerly() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let beforeName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Data([0x01]), fileName: beforeName)

        let beforeDir = storage.photosDirectory(for: .before)
        XCTAssertTrue(FileManager.default.fileExists(atPath: beforeDir.path))
        // After-kind directory should not be created until used.
        let afterDir = storage.photosDirectory(for: .after)
        XCTAssertFalse(FileManager.default.fileExists(atPath: afterDir.path))
    }

    func testRootDirectoryIsUnderConfiguredBase() {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        XCTAssertEqual(storage.rootDirectory, tempDir)
        XCTAssertTrue(storage.photosDirectory.path.hasPrefix(tempDir.path))
        XCTAssertTrue(storage.thumbnailsDirectory.path.hasPrefix(tempDir.path))
    }

    func testProductionInitDefaultsToDocumentsPairShot() {
        // No baseDirectory → resolves Documents/PairShot. Smoke check the
        // path shape; the FileManager call is exercised on a real device.
        let storage = PhotoStorageService()
        XCTAssertTrue(storage.rootDirectory.path.contains("Documents"))
        XCTAssertTrue(storage.rootDirectory.path.hasSuffix("PairShot"))
    }

    func testClearAllThumbnailsRemovesDirectory() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let thumbName = FileNameBuilder.thumbnail(forBaseName: "x.jpg")
        _ = try storage.saveThumbnailJPEG(Data([0x01]), kind: .before, fileName: thumbName)
        let dir = storage.thumbnailsDirectory
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))

        try storage.clearAllThumbnails()
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
    }

    deinit {}
}
