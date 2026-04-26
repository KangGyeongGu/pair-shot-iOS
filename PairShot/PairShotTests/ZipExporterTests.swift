import Foundation
@testable import PairShot
import SwiftData
import XCTest
import ZIPFoundation

/// P7.1 — ZIP archive bundling for export.
@MainActor
final class ZipExporterTests: XCTestCase {
    private var tempDir: URL!
    private var storage: PhotoStorageService!
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pairshot-zip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = PhotoStorageService(baseDirectory: tempDir)

        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        storage = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - happy paths

    func testMakeZipWritesArchiveContainingAllJPEGs() async throws {
        let project = Project(title: "현장 1")
        context.insert(project)
        let beforeRel = try storage.saveBeforeJPEG(Self.tinyJPEGBytes(seed: 1))
        let afterRel = try storage.saveAfterJPEG(Self.tinyJPEGBytes(seed: 2))
        let combinedRel = try storage.saveCombinedJPEG(Self.tinyJPEGBytes(seed: 3))
        let pair = PhotoPair(beforePath: beforeRel, project: project)
        pair.afterPath = afterRel
        pair.combinedPath = combinedRel
        pair.status = .complete
        context.insert(pair)
        try context.save()

        let exporter = ZipExporter()
        let zipURL = try await exporter.makeZip(
            for: [pair],
            mode: .all,
            storage: storage,
            in: tempDir,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))
        let archive = try Archive(url: zipURL, accessMode: .read)
        let names = archive.map(\.path).sorted()
        XCTAssertEqual(names.count, 3)
        for name in names {
            XCTAssertTrue(name.contains("_before.jpg")
                || name.contains("_after.jpg")
                || name.contains("_combined.jpg"))
        }
    }

    func testMakeZipUsesProjectTitleAsFolder() async throws {
        let project = Project(title: "Site_A")
        context.insert(project)
        let rel = try storage.saveBeforeJPEG(Self.tinyJPEGBytes(seed: 4))
        let pair = PhotoPair(beforePath: rel, project: project)
        context.insert(pair)
        try context.save()

        let exporter = ZipExporter()
        let zipURL = try await exporter.makeZip(
            for: [pair],
            mode: .beforeOnly,
            storage: storage,
            in: tempDir
        )

        let archive = try Archive(url: zipURL, accessMode: .read)
        let entries = Array(archive)
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].path.hasPrefix("Site_A/"))
        XCTAssertTrue(entries[0].path.hasSuffix("_before.jpg"))
    }

    func testMakeZipFileNameIsTimestamped() {
        let stamp = ZipExporter.makeFileName(now: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(stamp.hasPrefix("PairShot_"))
        XCTAssertTrue(stamp.hasSuffix(".zip"))
        XCTAssertTrue(stamp.contains("_")) // date_time separator inside name
    }

    func testMakeZipBeforeOnlyOmitsAfterAndCombined() async throws {
        let project = Project(title: "현장")
        context.insert(project)
        let beforeRel = try storage.saveBeforeJPEG(Self.tinyJPEGBytes(seed: 5))
        let afterRel = try storage.saveAfterJPEG(Self.tinyJPEGBytes(seed: 6))
        let pair = PhotoPair(beforePath: beforeRel, project: project)
        pair.afterPath = afterRel
        pair.status = .complete
        context.insert(pair)
        try context.save()

        let exporter = ZipExporter()
        let zipURL = try await exporter.makeZip(
            for: [pair],
            mode: .beforeOnly,
            storage: storage,
            in: tempDir
        )

        let archive = try Archive(url: zipURL, accessMode: .read)
        let names = Array(archive).map(\.path)
        XCTAssertEqual(names.count, 1)
        XCTAssertTrue(names[0].contains("_before.jpg"))
    }

    // MARK: - edge

    func testMakeZipEmptyPairsThrowsNoPairs() async {
        let exporter = ZipExporter()
        do {
            _ = try await exporter.makeZip(
                for: [],
                mode: .all,
                storage: storage,
                in: tempDir
            )
            XCTFail("Expected ZipExporter.ExportError.noPairs")
        } catch ZipExporter.ExportError.noPairs {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testMakeZipMissingSourceThrowsSourceMissing() async throws {
        let project = Project(title: "현장")
        context.insert(project)
        let pair = PhotoPair(
            beforePath: "photos/does-not-exist-\(UUID().uuidString).jpg",
            project: project
        )
        context.insert(pair)
        try context.save()

        let exporter = ZipExporter()
        do {
            _ = try await exporter.makeZip(
                for: [pair],
                mode: .beforeOnly,
                storage: storage,
                in: tempDir
            )
            XCTFail("Expected sourceMissing")
        } catch ZipExporter.ExportError.sourceMissing {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testMakeZipCombinedOnlyOnPendingPairProducesEmptyArchive() async throws {
        // pending pair has no combinedPath → ExportSelection returns empty,
        // so the archive ends up with zero entries (still valid file).
        let project = Project(title: "현장")
        context.insert(project)
        let beforeRel = try storage.saveBeforeJPEG(Self.tinyJPEGBytes(seed: 7))
        let pair = PhotoPair(beforePath: beforeRel, project: project)
        context.insert(pair)
        try context.save()

        let exporter = ZipExporter()
        let zipURL = try await exporter.makeZip(
            for: [pair],
            mode: .combinedOnly,
            storage: storage,
            in: tempDir
        )

        let archive = try Archive(url: zipURL, accessMode: .read)
        XCTAssertEqual(Array(archive).count, 0)
    }

    // MARK: - helpers

    private static func tinyJPEGBytes(seed: UInt8) -> Data {
        // Real JPEGs aren't required for ZIP packaging — `addEntry(fileURL:)`
        // streams raw bytes regardless of MIME. We just need >0 bytes per file.
        Data(repeating: seed, count: 256)
    }
}
