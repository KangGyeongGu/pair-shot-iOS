import Foundation
@testable import PairShot
import SwiftData
import XCTest
import ZIPFoundation

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

        let schema = Schema(versionedSchema: SchemaV2.self)
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

    func testMakeZipWritesArchiveContainingAllJPEGs() async throws {
        let beforeName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let afterName = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        let combinedName = FileNameBuilder.combined(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Self.tinyJPEGBytes(seed: 1), fileName: beforeName)
        _ = try storage.saveAfterJPEG(Self.tinyJPEGBytes(seed: 2), fileName: afterName)
        _ = try storage.saveCombinedJPEG(Self.tinyJPEGBytes(seed: 3), fileName: combinedName)

        let pair = PhotoPair(beforeFileName: beforeName)
        pair.afterFileName = afterName
        pair.combinedFileName = combinedName
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

    func testMakeZipUsesAlbumNameAsFolder() async throws {
        let album = Album(name: "Site_A")
        context.insert(album)

        let beforeName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(Self.tinyJPEGBytes(seed: 4), fileName: beforeName)
        let pair = PhotoPair(beforeFileName: beforeName)
        pair.albums.append(album)
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
    }

    private static func tinyJPEGBytes(seed: UInt8) -> Data {
        var bytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0]
        for i in 0 ..< 8 {
            bytes.append(seed &+ UInt8(i))
        }
        bytes.append(contentsOf: [0xFF, 0xD9])
        return Data(bytes)
    }

    deinit {}
}
