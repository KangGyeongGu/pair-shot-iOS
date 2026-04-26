import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P8.4 — directory size, orphan detection, and the supporting pure
/// helpers used by `StorageInfoView`.
///
/// Each test runs against a fresh temp directory so the storage
/// service can write/read/delete without touching the global
/// Application Support container. The SwiftData-backed test uses an
/// in-memory `ModelContainer` for the same reason.
final class StorageInfoTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pairshot-storage-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - directorySize — happy

    func testDirectorySizeReturnsZeroForFreshContainer() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        XCTAssertEqual(try storage.directorySize(), 0)
    }

    func testDirectorySizeSumsWrittenJpegs() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let payloadA = Data(repeating: 0xAA, count: 1024)
        let payloadB = Data(repeating: 0xBB, count: 2048)
        _ = try storage.saveBeforeJPEG(payloadA, fileID: UUID())
        _ = try storage.saveAfterJPEG(payloadB, fileID: UUID())

        let total = try storage.directorySize()
        // Allocated size is filesystem-dependent (typically a multiple
        // of the block size), so assert a sensible lower bound rather
        // than exact equality.
        XCTAssertGreaterThanOrEqual(total, Int64(payloadA.count + payloadB.count))
    }

    // MARK: - enumerateAllFiles — happy

    func testEnumerateAllFilesListsExactlyTheWrittenSet() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let idA = UUID()
        let idB = UUID()
        let pathA = try storage.saveBeforeJPEG(Data([0x01]), fileID: idA)
        let pathB = try storage.saveAfterJPEG(Data([0x02]), fileID: idB)

        let listed = try storage.enumerateAllFiles()
            .map(\.lastPathComponent)
            .sorted()
        let expected = [pathA, pathB]
            .map { ($0 as NSString).lastPathComponent }
            .sorted()
        XCTAssertEqual(listed, expected)
    }

    // MARK: - orphanFiles — happy + edge

    func testOrphanFilesReturnsFilesNotReferenced() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let kept = try storage.saveBeforeJPEG(Data([0x01]), fileID: UUID())
        _ = try storage.saveAfterJPEG(Data([0x02]), fileID: UUID()) // orphan

        let orphans = try storage.orphanFiles(referencedRelativePaths: [kept])
        XCTAssertEqual(orphans.count, 1)
        XCTAssertNotEqual(
            orphans.first?.lastPathComponent,
            (kept as NSString).lastPathComponent
        )
    }

    func testOrphanFilesEmptyWhenAllReferenced() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let pathA = try storage.saveBeforeJPEG(Data([0x01]), fileID: UUID())
        let pathB = try storage.saveAfterJPEG(Data([0x02]), fileID: UUID())

        let orphans = try storage.orphanFiles(
            referencedRelativePaths: [pathA, pathB]
        )
        XCTAssertTrue(orphans.isEmpty)
    }

    func testOrphanFilesEmptyForFreshContainer() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let orphans = try storage.orphanFiles(referencedRelativePaths: [])
        XCTAssertTrue(orphans.isEmpty)
    }

    // MARK: - deleteOrphanFiles — happy

    func testDeleteOrphanFilesRemovesUnreferencedAndReportsCounts() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let kept = try storage.saveBeforeJPEG(Data(repeating: 0x10, count: 256), fileID: UUID())
        let orphan1 = try storage.saveAfterJPEG(Data(repeating: 0x20, count: 512), fileID: UUID())
        let orphan2 = try storage.saveCombinedJPEG(Data(repeating: 0x30, count: 1024), fileID: UUID())

        let result = try storage.deleteOrphanFiles(referencedRelativePaths: [kept])
        XCTAssertEqual(result.deletedCount, 2)
        XCTAssertGreaterThanOrEqual(result.freedBytes, Int64(512 + 1024))

        // Kept file remains; orphans are gone.
        let remaining = try storage.enumerateAllFiles().map(\.lastPathComponent)
        XCTAssertEqual(remaining, [(kept as NSString).lastPathComponent])
        XCTAssertFalse(remaining.contains((orphan1 as NSString).lastPathComponent))
        XCTAssertFalse(remaining.contains((orphan2 as NSString).lastPathComponent))
    }

    // MARK: - StorageInfoMath — pure helpers

    @MainActor
    func testReferencedRelativePathsUnionsAllThreeRoles() throws {
        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let project = Project(title: "현장")
        context.insert(project)

        let p1 = PhotoPair(beforePath: "photos/b1.jpg", project: project)
        p1.afterPath = "photos/a1.jpg"
        p1.combinedPath = "photos/c1.jpg"
        context.insert(p1)

        let p2 = PhotoPair(beforePath: "photos/b2.jpg", project: project)
        // p2 is mid-capture: only beforePath set.
        context.insert(p2)
        try context.save()

        let referenced = StorageInfoMath.referencedRelativePaths(in: project.pairs)
        XCTAssertEqual(referenced, [
            "photos/b1.jpg",
            "photos/a1.jpg",
            "photos/c1.jpg",
            "photos/b2.jpg",
        ])
    }

    @MainActor
    func testReferencedRelativePathsSkipsEmptyAndNilPaths() throws {
        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let project = Project(title: "현장")
        context.insert(project)
        let pair = PhotoPair(beforePath: "", project: project)
        pair.afterPath = ""
        pair.combinedPath = nil
        context.insert(pair)
        try context.save()

        XCTAssertTrue(StorageInfoMath.referencedRelativePaths(in: project.pairs).isEmpty)
    }

    func testFormatBytesUsesByteCountFormatter() {
        // We don't pin exact strings (locale-dependent: iOS may render
        // "Zero KB" for 0 input when `allowsNonnumericFormatting` is on).
        // Instead assert (a) non-empty, (b) the 0-input and 1MB-input
        // strings differ, and (c) a negative value clamps to the same
        // "zero" rendering.
        let zero = StorageInfoMath.formatBytes(0)
        XCTAssertFalse(zero.isEmpty)

        let oneMB = StorageInfoMath.formatBytes(1_048_576)
        XCTAssertFalse(oneMB.isEmpty)
        XCTAssertNotEqual(oneMB, zero)

        // Negative input clamps to 0 rather than rendering "-1 MB".
        let negative = StorageInfoMath.formatBytes(-100)
        XCTAssertEqual(negative, zero)
    }

    func testFilenameStripsLeadingDirectory() {
        XCTAssertEqual(PhotoStorageService.filename(from: "photos/abc.jpg"), "abc.jpg")
        XCTAssertEqual(PhotoStorageService.filename(from: "abc.jpg"), "abc.jpg")
        XCTAssertNil(PhotoStorageService.filename(from: ""))
    }
}
