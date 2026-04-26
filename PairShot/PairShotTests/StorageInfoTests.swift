import Foundation
@testable import PairShot
import SwiftData
import XCTest

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

    func testDirectorySizeReturnsZeroForFreshContainer() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        XCTAssertEqual(try storage.directorySize(), 0)
    }

    func testDirectorySizeSumsWrittenJpegs() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let payloadA = Data(repeating: 0xAA, count: 1024)
        let payloadB = Data(repeating: 0xBB, count: 2048)
        let nameA = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let nameB = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(payloadA, fileName: nameA)
        _ = try storage.saveAfterJPEG(payloadB, fileName: nameB)

        let total = try storage.directorySize()
        XCTAssertGreaterThanOrEqual(total, Int64(payloadA.count + payloadB.count))
    }

    func testEnumerateAllFilesListsExactlyTheWrittenSet() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let nameA = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let nameB = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Data([0x01]), fileName: nameA)
        _ = try storage.saveAfterJPEG(Data([0x02]), fileName: nameB)

        let listed = try storage.enumerateAllFiles()
            .map(\.lastPathComponent)
            .sorted()
        XCTAssertEqual(listed, [nameA, nameB].sorted())
    }

    func testOrphanFilesReturnsFilesNotReferenced() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let kept = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let orphan = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Data([0x01]), fileName: kept)
        _ = try storage.saveAfterJPEG(Data([0x02]), fileName: orphan)

        let orphans = try storage.orphanFiles(referencedFileNames: [kept])
        XCTAssertEqual(orphans.count, 1)
        XCTAssertEqual(orphans.first?.lastPathComponent, orphan)
    }

    func testOrphanFilesEmptyWhenAllReferenced() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let nameA = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let nameB = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Data([0x01]), fileName: nameA)
        _ = try storage.saveAfterJPEG(Data([0x02]), fileName: nameB)

        let orphans = try storage.orphanFiles(referencedFileNames: [nameA, nameB])
        XCTAssertTrue(orphans.isEmpty)
    }

    func testOrphanFilesEmptyForFreshContainer() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let orphans = try storage.orphanFiles(referencedFileNames: [])
        XCTAssertTrue(orphans.isEmpty)
    }

    func testDeleteOrphanFilesRemovesUnreferencedAndReportsCounts() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let kept = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let orphan1 = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        let orphan2 = FileNameBuilder.combined(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Data(repeating: 0x10, count: 256), fileName: kept)
        _ = try storage.saveAfterJPEG(Data(repeating: 0x20, count: 512), fileName: orphan1)
        _ = try storage.saveCombinedJPEG(Data(repeating: 0x30, count: 1024), fileName: orphan2)

        let result = try storage.deleteOrphanFiles(referencedFileNames: [kept])
        XCTAssertEqual(result.deletedCount, 2)
        XCTAssertGreaterThanOrEqual(result.freedBytes, Int64(512 + 1024))

        let remaining = try storage.enumerateAllFiles().map(\.lastPathComponent)
        XCTAssertEqual(remaining, [kept])
    }

    @MainActor
    func testReferencedFileNamesUnionsAllThreeRoles() {
        let pair = PhotoPair(beforeFileName: "before_one.jpg")
        pair.afterFileName = "after_one.jpg"
        pair.combinedFileName = "combined_one.jpg"

        let pair2 = PhotoPair(beforeFileName: "before_two.jpg")

        let referenced = StorageInfoMath.referencedFileNames(in: [pair, pair2])
        XCTAssertEqual(referenced, [
            "before_one.jpg",
            "after_one.jpg",
            "combined_one.jpg",
            "before_two.jpg",
        ])
    }

    @MainActor
    func testReferencedFileNamesSkipsEmptyAndNilPaths() {
        let pair = PhotoPair(beforeFileName: "")
        pair.afterFileName = ""
        pair.combinedFileName = nil
        XCTAssertTrue(StorageInfoMath.referencedFileNames(in: [pair]).isEmpty)
    }

    func testFormatBytesUsesByteCountFormatter() {
        let zero = StorageInfoMath.formatBytes(0)
        XCTAssertFalse(zero.isEmpty)
        let oneMB = StorageInfoMath.formatBytes(1_048_576)
        XCTAssertNotEqual(oneMB, zero)
        XCTAssertEqual(StorageInfoMath.formatBytes(-100), zero)
    }

    deinit {}
}
