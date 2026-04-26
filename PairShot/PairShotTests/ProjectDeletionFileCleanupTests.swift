import Foundation
@testable import PairShot
import SwiftData
import UIKit
import XCTest

/// Audit-A — verifies `ProjectDeletionService.deleteProjects` cascades
/// to the underlying JPEG files and the in-memory thumbnail cache, not
/// just the SwiftData rows. Until this fix, deleted projects orphaned
/// their files in `Application Support/photos/`, ballooning user
/// storage with ghosts of "deleted" data.
@MainActor
final class ProjectDeletionFileCleanupTests: XCTestCase {
    private var container: ModelContainer!
    private var tempDir: URL!
    private var storage: PhotoStorageService!

    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-a-deletion-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = PhotoStorageService(baseDirectory: tempDir)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        container = nil
        storage = nil
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - happy paths

    func testDeleteProjectRemovesAllPairFilesFromDisk() throws {
        let project = Project(title: "현장-삭제")
        context.insert(project)

        // Two pairs × (before + after) = 4 JPEGs on disk.
        let beforeA = try storage.saveBeforeJPEG(Data([0x01]))
        let afterA = try storage.saveAfterJPEG(Data([0x02]))
        let beforeB = try storage.saveBeforeJPEG(Data([0x03]))
        let afterB = try storage.saveAfterJPEG(Data([0x04]))

        let pairA = PhotoPair(beforePath: beforeA, project: project)
        pairA.afterPath = afterA
        let pairB = PhotoPair(beforePath: beforeB, project: project)
        pairB.afterPath = afterB
        context.insert(pairA)
        context.insert(pairB)
        try context.save()

        // Sanity — 4 files exist before the delete.
        let preCount = try storage.enumerateAllFiles().count
        XCTAssertEqual(preCount, 4, "expected 4 JPEGs on disk before deletion")

        let removed = try ProjectDeletionService.deleteProjects(
            ids: [project.id],
            in: context,
            storage: storage
        )

        XCTAssertEqual(removed, 1)
        let postCount = try storage.enumerateAllFiles().count
        XCTAssertEqual(postCount, 0, "all JPEGs must be unlinked when their project is deleted")
        let projects = try context.fetch(FetchDescriptor<Project>())
        XCTAssertTrue(projects.isEmpty)
        let pairs = try context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertTrue(pairs.isEmpty, "SwiftData cascade should still clean the rows")
    }

    func testDeleteProjectAlsoRemovesCombinedPath() throws {
        let project = Project(title: "합성포함")
        context.insert(project)

        let before = try storage.saveBeforeJPEG(Data([0x10]))
        let after = try storage.saveAfterJPEG(Data([0x11]))
        let combined = try storage.saveCombinedJPEG(Data([0x12]))

        let pair = PhotoPair(beforePath: before, project: project)
        pair.afterPath = after
        pair.combinedPath = combined
        pair.status = .complete
        context.insert(pair)
        try context.save()

        XCTAssertEqual(try storage.enumerateAllFiles().count, 3)

        try ProjectDeletionService.deleteProjects(
            ids: [project.id],
            in: context,
            storage: storage
        )

        XCTAssertEqual(
            try storage.enumerateAllFiles().count,
            0,
            "combinedPath must also be unlinked"
        )
    }

    func testDeleteProjectEvictsThumbnailCacheEntries() throws {
        let project = Project(title: "썸네일 캐시")
        context.insert(project)

        // Save a real JPEG so `ThumbnailCache.loadThumbnail` can decode
        // and seed the cache via the production path.
        let realJPEG = Self.makeOnePixelJPEG()
        let before = try storage.saveBeforeJPEG(realJPEG)
        let pair = PhotoPair(beforePath: before, project: project)
        context.insert(pair)
        try context.save()

        // Use the singleton (the one ProjectDeletionService evicts).
        ThumbnailCache.shared.removeAll()
        let seeded = ThumbnailCache.shared.loadThumbnail(
            forRelativePath: before,
            storage: storage
        )
        XCTAssertNotNil(seeded, "precondition: thumbnail must decode for the test to be meaningful")
        XCTAssertNotNil(
            ThumbnailCache.shared.cached(forRelativePath: before),
            "precondition: cache hit before delete"
        )

        try ProjectDeletionService.deleteProjects(
            ids: [project.id],
            in: context,
            storage: storage
        )

        XCTAssertNil(
            ThumbnailCache.shared.cached(forRelativePath: before),
            "thumbnail cache must be evicted on project delete"
        )
    }

    /// Synthesises a 1×1 JPEG so `ThumbnailCache.downsample` can decode
    /// without hitting the filesystem for a real photo.
    private static func makeOnePixelJPEG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    // MARK: - edge

    func testDeleteProjectIsRobustWhenFilesAlreadyMissing() throws {
        let project = Project(title: "고아")
        context.insert(project)
        // Insert a pair whose `beforePath` doesn't exist on disk.
        let pair = PhotoPair(
            beforePath: "photos/does-not-exist.jpg",
            project: project
        )
        context.insert(pair)
        try context.save()

        // Should not throw — file deletion is best-effort.
        let removed = try ProjectDeletionService.deleteProjects(
            ids: [project.id],
            in: context,
            storage: storage
        )
        XCTAssertEqual(removed, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Project>()).isEmpty)
    }

    func testDeleteOneProjectDoesNotTouchOtherProjectsFiles() throws {
        let keep = Project(title: "유지")
        let drop = Project(title: "삭제")
        context.insert(keep)
        context.insert(drop)

        let keepBefore = try storage.saveBeforeJPEG(Data([0x55]))
        let dropBefore = try storage.saveBeforeJPEG(Data([0x66]))
        context.insert(PhotoPair(beforePath: keepBefore, project: keep))
        context.insert(PhotoPair(beforePath: dropBefore, project: drop))
        try context.save()
        XCTAssertEqual(try storage.enumerateAllFiles().count, 2)

        try ProjectDeletionService.deleteProjects(
            ids: [drop.id],
            in: context,
            storage: storage
        )

        let remaining = try storage.enumerateAllFiles()
        XCTAssertEqual(remaining.count, 1, "only the deleted project's files should be removed")
        XCTAssertEqual(
            remaining.first?.lastPathComponent,
            (keepBefore as NSString).lastPathComponent,
            "the surviving project's file must remain intact"
        )
    }
}
