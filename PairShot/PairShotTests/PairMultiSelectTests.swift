import Foundation
@testable import PairShot
import SwiftData
import XCTest

@MainActor
final class PairMultiSelectTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    private var tempDir: URL!
    private var storage: PhotoStorageService!

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pairshot-pair-multi-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = PhotoStorageService(baseDirectory: tempDir)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        container = nil
        storage = nil
        tempDir = nil
    }

    func testSelectionTogglesIds() {
        let s = PairSelection()
        let id1 = UUID()
        let id2 = UUID()

        s.toggle(id1)
        XCTAssertTrue(s.contains(id1))
        XCTAssertEqual(s.count, 1)

        s.toggle(id2)
        XCTAssertEqual(s.count, 2)

        s.toggle(id1)
        XCTAssertFalse(s.contains(id1))
        XCTAssertEqual(s.count, 1)
    }

    func testSelectionEnterAndExit() {
        let s = PairSelection()
        let id = UUID()
        XCTAssertFalse(s.isSelectionMode)
        s.enterSelection(with: id)
        XCTAssertTrue(s.isSelectionMode)
        XCTAssertEqual(s.selectedIds, [id])
        s.exit()
        XCTAssertFalse(s.isSelectionMode)
        XCTAssertTrue(s.selectedIds.isEmpty)
    }

    func testDeletePairsRemovesRowsAndUnderlyingFiles() throws {
        let beforeName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let afterName = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        let combinedName = FileNameBuilder.combined(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Data([0x01, 0x02]), fileName: beforeName)
        _ = try storage.saveAfterJPEG(Data([0x03, 0x04]), fileName: afterName)
        _ = try storage.saveCombinedJPEG(Data([0x05, 0x06]), fileName: combinedName)

        let pair = PhotoPair(beforeFileName: beforeName)
        pair.afterFileName = afterName
        pair.combinedFileName = combinedName
        context.insert(pair)
        try context.save()

        let beforeURL = try XCTUnwrap(storage.resolve(kind: .before, fileName: beforeName))
        let afterURL = try XCTUnwrap(storage.resolve(kind: .after, fileName: afterName))
        let combinedURL = try XCTUnwrap(storage.resolve(kind: .combined, fileName: combinedName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: beforeURL.path))

        let deleted = try PairDeletionService.deletePairs(
            ids: [pair.id], in: context, storage: storage
        )
        XCTAssertEqual(deleted, 1)

        let remaining = try context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertTrue(remaining.isEmpty)

        XCTAssertFalse(FileManager.default.fileExists(atPath: beforeURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: afterURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: combinedURL.path))
    }

    func testDeletePairsLeavesUnselectedPairsUntouched() throws {
        let keptName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let removedName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Data([0xAA]), fileName: keptName)
        _ = try storage.saveBeforeJPEG(Data([0xBB]), fileName: removedName)

        let kept = PhotoPair(beforeFileName: keptName)
        let removed = PhotoPair(beforeFileName: removedName)
        context.insert(kept)
        context.insert(removed)
        try context.save()

        let deleted = try PairDeletionService.deletePairs(
            ids: [removed.id], in: context, storage: storage
        )
        XCTAssertEqual(deleted, 1)

        let remaining = try context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertEqual(remaining.map(\.beforeFileName), [keptName])

        let keptURL = try XCTUnwrap(storage.resolve(kind: .before, fileName: keptName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: keptURL.path))
    }

    func testDeleteEmptySetIsNoOp() throws {
        let pair = PhotoPair(beforeFileName: "a.jpg")
        context.insert(pair)
        try context.save()

        let deleted = try PairDeletionService.deletePairs(ids: [], in: context, storage: storage)
        XCTAssertEqual(deleted, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PhotoPair>()).count, 1)
    }

    func testDeleteWithUnknownIdRemovesNothing() throws {
        let pair = PhotoPair(beforeFileName: "a.jpg")
        context.insert(pair)
        try context.save()

        let deleted = try PairDeletionService.deletePairs(ids: [UUID()], in: context, storage: storage)
        XCTAssertEqual(deleted, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PhotoPair>()).count, 1)
    }

    func testDeleteSucceedsEvenIfFilesAreAlreadyMissing() throws {
        let pair = PhotoPair(beforeFileName: "ghost-\(UUID().uuidString).jpg")
        context.insert(pair)
        try context.save()

        let deleted = try PairDeletionService.deletePairs(
            ids: [pair.id], in: context, storage: storage
        )
        XCTAssertEqual(deleted, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PhotoPair>()).count, 0)
    }

    deinit {}
}
