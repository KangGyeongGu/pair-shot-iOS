import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P4.3 — `PairSelection` toggling + `PairDeletionService` (rows + JPEG files).
@MainActor
final class PairMultiSelectTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    private var tempDir: URL!
    private var storage: PhotoStorageService!

    override func setUpWithError() throws {
        let schema = Schema([Project.self, PhotoPair.self])
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

    // MARK: - selection

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

    // MARK: - deletion (happy)

    func testDeletePairsRemovesRowsAndUnderlyingFiles() throws {
        let project = Project(title: "현장")
        context.insert(project)

        // Save two real JPEG-like blobs to disk so we can verify deletion.
        let beforeRel = try storage.saveBeforeJPEG(Data([0x01, 0x02]))
        let afterRel = try storage.saveAfterJPEG(Data([0x03, 0x04]))
        let combinedRel = try storage.saveBeforeJPEG(Data([0x05, 0x06]))

        let pair = PhotoPair(beforePath: beforeRel, project: project)
        pair.afterPath = afterRel
        pair.combinedPath = combinedRel
        pair.status = .complete
        context.insert(pair)
        try context.save()

        let beforeURL = try XCTUnwrap(storage.resolve(relativePath: beforeRel))
        let afterURL = try XCTUnwrap(storage.resolve(relativePath: afterRel))
        let combinedURL = try XCTUnwrap(storage.resolve(relativePath: combinedRel))

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
        let project = Project(title: "현장")
        context.insert(project)

        let keptRel = try storage.saveBeforeJPEG(Data([0xAA]))
        let removedRel = try storage.saveBeforeJPEG(Data([0xBB]))

        let kept = PhotoPair(beforePath: keptRel, project: project)
        let removed = PhotoPair(beforePath: removedRel, project: project)
        context.insert(kept)
        context.insert(removed)
        try context.save()

        let deleted = try PairDeletionService.deletePairs(
            ids: [removed.id], in: context, storage: storage
        )
        XCTAssertEqual(deleted, 1)

        let remaining = try context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertEqual(remaining.map(\.beforePath), [keptRel])

        let keptURL = try XCTUnwrap(storage.resolve(relativePath: keptRel))
        XCTAssertTrue(FileManager.default.fileExists(atPath: keptURL.path))
    }

    // MARK: - deletion (edge)

    func testDeleteEmptySetIsNoOp() throws {
        let project = Project(title: "현장")
        context.insert(project)
        let pair = PhotoPair(beforePath: "p/a.jpg", project: project)
        context.insert(pair)
        try context.save()

        let deleted = try PairDeletionService.deletePairs(
            ids: [], in: context, storage: storage
        )
        XCTAssertEqual(deleted, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PhotoPair>()).count, 1)
    }

    func testDeleteWithUnknownIdRemovesNothing() throws {
        let project = Project(title: "현장")
        context.insert(project)
        let pair = PhotoPair(beforePath: "p/a.jpg", project: project)
        context.insert(pair)
        try context.save()

        let deleted = try PairDeletionService.deletePairs(
            ids: [UUID()], in: context, storage: storage
        )
        XCTAssertEqual(deleted, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PhotoPair>()).count, 1)
    }

    func testDeleteSucceedsEvenIfFilesAreAlreadyMissing() throws {
        let project = Project(title: "현장")
        context.insert(project)

        let pair = PhotoPair(beforePath: "photos/ghost-\(UUID().uuidString).jpg", project: project)
        context.insert(pair)
        try context.save()

        let deleted = try PairDeletionService.deletePairs(
            ids: [pair.id], in: context, storage: storage
        )
        XCTAssertEqual(deleted, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PhotoPair>()).count, 0)
    }
}
