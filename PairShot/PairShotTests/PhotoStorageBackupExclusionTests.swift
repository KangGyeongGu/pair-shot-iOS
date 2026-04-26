import Foundation
@testable import PairShot
import XCTest

/// Audit-A — verifies that `PhotoStorageService.ensureDirectoryExists()`
/// (invoked transitively from any `save*JPEG` call) flips the photos
/// directory's `isExcludedFromBackup` URL resource value to `true`.
///
/// Without this flag, captured JPEGs land under `Application Support`
/// which is iCloud-Backup-eligible by default — every shoot would
/// silently consume the user's backup quota.
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

    /// Reads the `isExcludedFromBackup` resource value off `url`.
    /// Returns `nil` when the value isn't readable on this filesystem
    /// (eg. exotic test sandboxes) so callers can skip cleanly.
    private func isExcludedFromBackup(_ url: URL) throws -> Bool? {
        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return values.isExcludedFromBackup
    }

    // MARK: - happy

    func testPhotosDirectoryFlaggedExcludedAfterFirstSave() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        // Trigger directory creation via the production save path.
        _ = try storage.saveBeforeJPEG(Data([0xFE]))

        let dir = storage.photosDirectory
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))

        guard let excluded = try isExcludedFromBackup(dir) else {
            throw XCTSkip("filesystem does not expose isExcludedFromBackup — likely Linux CI")
        }
        XCTAssertTrue(excluded, "photos directory must be excluded from iCloud Backup")
    }

    func testFlagIsIdempotentAcrossMultipleSaves() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        _ = try storage.saveBeforeJPEG(Data([0x01]))
        _ = try storage.saveAfterJPEG(Data([0x02]))
        _ = try storage.saveCombinedJPEG(Data([0x03]))

        let dir = storage.photosDirectory
        guard let excluded = try isExcludedFromBackup(dir) else {
            throw XCTSkip("filesystem does not expose isExcludedFromBackup")
        }
        XCTAssertTrue(excluded, "flag must remain set after repeat saves")
    }

    // MARK: - edge

    func testMarkExcludedFromBackupHelperRoundTrips() throws {
        // Verify the `markExcludedFromBackup(_:)` helper alone — handy
        // when wiring a future callsite that wants the same behaviour
        // without going through `ensureDirectoryExists()`.
        let dir = tempDir.appendingPathComponent("manual-mark", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var mutableURL = dir
        try PhotoStorageService.markExcludedFromBackup(&mutableURL)
        guard let excluded = try isExcludedFromBackup(dir) else {
            throw XCTSkip("filesystem does not expose isExcludedFromBackup")
        }
        XCTAssertTrue(excluded)
    }
}
