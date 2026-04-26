import Foundation
@testable import PairShot
import SwiftData
import UIKit
import XCTest

@MainActor
final class CompositeRendererTests: XCTestCase {
    private var tempDir: URL!
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pairshot-composite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        container = nil
        try super.tearDownWithError()
    }

    func testHorizontalLayoutCanvasIsSumOfWidthsAtCommonHeight() {
        let frames = CompositeRenderer.composeFrames(
            beforeSize: CGSize(width: 200, height: 100),
            afterSize: CGSize(width: 100, height: 50),
            layout: .horizontal
        )
        XCTAssertEqual(frames.canvas.width, 200, accuracy: 1e-6)
        XCTAssertEqual(frames.canvas.height, 50, accuracy: 1e-6)
        XCTAssertEqual(frames.beforeRect, CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(frames.afterRect, CGRect(x: 100, y: 0, width: 100, height: 50))
    }

    func testVerticalLayoutCanvasIsSumOfHeightsAtCommonWidth() {
        let frames = CompositeRenderer.composeFrames(
            beforeSize: CGSize(width: 100, height: 200),
            afterSize: CGSize(width: 200, height: 100),
            layout: .vertical
        )
        XCTAssertEqual(frames.canvas.width, 100, accuracy: 1e-6)
        XCTAssertEqual(frames.canvas.height, 250, accuracy: 1e-6)
        XCTAssertEqual(frames.beforeRect, CGRect(x: 0, y: 0, width: 100, height: 200))
        XCTAssertEqual(frames.afterRect, CGRect(x: 0, y: 200, width: 100, height: 50))
    }

    func testRenderCompositeProducesNonZeroImageHorizontal() {
        let before = makeSolidImage(size: CGSize(width: 80, height: 60), color: .red)
        let after = makeSolidImage(size: CGSize(width: 60, height: 60), color: .green)
        let composite = CompositeRenderer.renderComposite(
            before: before, after: after, layout: .horizontal
        )
        XCTAssertEqual(composite.size.width, 140, accuracy: 1.0)
        XCTAssertEqual(composite.size.height, 60, accuracy: 1.0)
    }

    func testRenderCompositeProducesNonZeroImageVertical() {
        let before = makeSolidImage(size: CGSize(width: 80, height: 60), color: .red)
        let after = makeSolidImage(size: CGSize(width: 80, height: 40), color: .green)
        let composite = CompositeRenderer.renderComposite(
            before: before, after: after, layout: .vertical
        )
        XCTAssertEqual(composite.size.width, 80, accuracy: 1.0)
        XCTAssertEqual(composite.size.height, 100, accuracy: 1.0)
    }

    func testMakeCompositeWritesCombinedFileNameAndPersists() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let pair = try makePopulatedPair(storage: storage)

        let opts = CompositeOptions(layout: .horizontal, jpegQuality: 0.8, watermarkEnabled: false)
        let combinedFileName = try await CompositeRenderer.makeComposite(
            for: pair,
            options: opts,
            storage: storage,
            in: context
        )

        XCTAssertTrue(combinedFileName.hasSuffix(".jpg"))
        XCTAssertEqual(pair.combinedFileName, combinedFileName)

        let absolute = try XCTUnwrap(storage.resolve(kind: .combined, fileName: combinedFileName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: absolute.path))

        let restored = try Data(contentsOf: absolute)
        XCTAssertGreaterThan(restored.count, 0)
        XCTAssertEqual(restored[0], 0xFF)
        XCTAssertEqual(restored[1], 0xD8)
    }

    func testMakeCompositeBumpsAlbumUpdatedAt() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let album = Album(name: "T")
        album.updatedAt = Date(timeIntervalSince1970: 1000)
        context.insert(album)

        let pair = try makePopulatedPair(storage: storage)
        pair.albums.append(album)
        try context.save()

        let now = Date(timeIntervalSince1970: 9999)
        _ = try await CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .vertical, jpegQuality: 0.7, watermarkEnabled: false),
            storage: storage,
            in: context,
            now: now
        )
        XCTAssertEqual(album.updatedAt, now)
    }

    func testMakeCompositeThrowsWhenAfterPathMissing() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let beforeName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let before = makeSolidImage(size: CGSize(width: 30, height: 30), color: .gray)
        _ = try storage.saveBeforeJPEG(
            XCTUnwrap(before.jpegData(compressionQuality: 0.9)),
            fileName: beforeName
        )

        let pair = PhotoPair(beforeFileName: beforeName)
        context.insert(pair)
        try context.save()

        do {
            _ = try await CompositeRenderer.makeComposite(
                for: pair,
                storage: storage,
                in: context
            )
            XCTFail("expected makeComposite to throw afterPathNotSet")
        } catch let error as CompositeRenderer.RenderError {
            XCTAssertEqual(error, .afterPathNotSet)
        }
    }

    func testMakeCompositeThrowsWhenBeforeFileMissing() async throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let after = makeSolidImage(size: CGSize(width: 30, height: 30), color: .gray)
        let afterName = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveAfterJPEG(
            XCTUnwrap(after.jpegData(compressionQuality: 0.9)),
            fileName: afterName
        )

        let pair = PhotoPair(beforeFileName: "missing-\(UUID().uuidString).jpg")
        pair.afterFileName = afterName
        context.insert(pair)
        try context.save()

        do {
            _ = try await CompositeRenderer.makeComposite(
                for: pair,
                storage: storage,
                in: context
            )
            XCTFail("expected makeComposite to throw beforeImageMissing")
        } catch let error as CompositeRenderer.RenderError {
            XCTAssertEqual(error, .beforeImageMissing)
        }
    }

    func testComposeFramesHandlesZeroDimensionsDefensively() {
        let frames = CompositeRenderer.composeFrames(
            beforeSize: .zero,
            afterSize: CGSize(width: 100, height: 100),
            layout: .horizontal
        )
        XCTAssertGreaterThan(frames.canvas.width, 0)
        XCTAssertGreaterThan(frames.canvas.height, 0)
    }

    func testCompositeLayoutAllCasesHaveDistinctLabels() {
        XCTAssertEqual(CompositeLayout.allCases.count, 2)
        XCTAssertNotEqual(CompositeLayout.horizontal.label, CompositeLayout.vertical.label)
        XCTAssertFalse(CompositeLayout.horizontal.label.isEmpty)
        XCTAssertFalse(CompositeLayout.vertical.label.isEmpty)
    }

    private func makePopulatedPair(storage: PhotoStorageService) throws -> PhotoPair {
        let before = makeSolidImage(size: CGSize(width: 60, height: 40), color: .blue)
        let after = makeSolidImage(size: CGSize(width: 60, height: 40), color: .yellow)
        let beforeData = try XCTUnwrap(before.jpegData(compressionQuality: 0.9))
        let afterData = try XCTUnwrap(after.jpegData(compressionQuality: 0.9))
        let beforeName = FileNameBuilder.before(prefix: "", timestamp: .now, pairId: UUID())
        let afterName = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: UUID())
        _ = try storage.saveBeforeJPEG(beforeData, fileName: beforeName)
        _ = try storage.saveAfterJPEG(afterData, fileName: afterName)
        let pair = PhotoPair(beforeFileName: beforeName)
        pair.afterFileName = afterName
        context.insert(pair)
        try context.save()
        return pair
    }

    private func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    deinit {}
}
