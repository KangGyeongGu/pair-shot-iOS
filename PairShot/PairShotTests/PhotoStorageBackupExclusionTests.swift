import Foundation
@testable import PairShot
import XCTest

final class PhotoStorageBackupExclusionTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-a-backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    private func isExcludedFromBackup(_ url: URL) throws -> Bool? {
        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return values.isExcludedFromBackup
    }

    func testPhotosDirectoryIsIncludedInBackupAfterFirstSave() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let fileName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Data([0xFE]), fileName: fileName)

        let dir = storage.photosDirectory(for: .before)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))

        guard let excluded = try isExcludedFromBackup(dir) else {
            throw XCTSkip("filesystem does not expose isExcludedFromBackup — likely Linux CI")
        }
        XCTAssertFalse(excluded, "photos directory must be included in iCloud Backup (user data)")
    }

    func testThumbnailsDirectoryIsExcludedFromBackup() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let fileName = FileNameBuilder.thumbnail(forBaseName: "x.jpg")
        _ = try storage.saveThumbnailJPEG(Data([0x01]), kind: .before, fileName: fileName)

        let dir = storage.thumbnailsDirectory(for: .before)
        guard let excluded = try isExcludedFromBackup(dir) else {
            throw XCTSkip("filesystem does not expose isExcludedFromBackup")
        }
        XCTAssertTrue(excluded, "thumbnails directory must be excluded from iCloud Backup")
    }

    func testFlagPolicyIsIdempotentAcrossMultipleSaves() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        for _ in 0 ..< 3 {
            let beforeName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
            _ = try storage.saveBeforeJPEG(Data([0x01]), fileName: beforeName)
        }
        let dir = storage.photosDirectory(for: .before)
        guard let excluded = try isExcludedFromBackup(dir) else {
            throw XCTSkip("filesystem does not expose isExcludedFromBackup")
        }
        XCTAssertFalse(excluded, "policy must remain stable after repeat saves")
    }

    func testMarkExcludedFromBackupHelperRoundTrips() throws {
        let dir = tempDir.appendingPathComponent("manual-mark", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var mutableURL = dir
        try PhotoStorageService.markExcludedFromBackup(&mutableURL)
        guard let excluded = try isExcludedFromBackup(dir) else {
            throw XCTSkip("filesystem does not expose isExcludedFromBackup")
        }
        XCTAssertTrue(excluded)
    }

    deinit {}
}
