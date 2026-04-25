import Foundation
@testable import PairShot
import SwiftData
import UIKit
import XCTest

/// P5.2 — `CompositeRenderer` geometry + persistence behaviour.
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

        let schema = Schema([Project.self, PhotoPair.self])
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

    // MARK: - happy

    func testHorizontalLayoutCanvasIsSumOfWidthsAtCommonHeight() {
        let frames = CompositeRenderer.composeFrames(
            beforeSize: CGSize(width: 200, height: 100),
            afterSize: CGSize(width: 100, height: 50),
            layout: .horizontal
        )
        // commonHeight = min(100, 50) = 50.
        // beforeWidth scaled = 200 * (50/100) = 100; afterWidth scaled =
        // 100 * (50/50) = 100. Canvas = 200×50.
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
        // commonWidth = 100. beforeHeight scaled = 200; afterHeight = 50.
        // Canvas = 100×250.
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

    func testMakeCompositeWritesCombinedPathAndPersists() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        // Two synthetic JPEGs on disk.
        let before = makeSolidImage(size: CGSize(width: 60, height: 40), color: .blue)
        let after = makeSolidImage(size: CGSize(width: 60, height: 40), color: .yellow)
        let beforeData = try XCTUnwrap(before.jpegData(compressionQuality: 0.9))
        let afterData = try XCTUnwrap(after.jpegData(compressionQuality: 0.9))
        let beforePath = try storage.saveBeforeJPEG(beforeData)
        let afterPath = try storage.saveAfterJPEG(afterData)

        let project = Project(title: "현장")
        context.insert(project)
        let pair = PhotoPair(beforePath: beforePath, project: project)
        pair.afterPath = afterPath
        pair.status = .complete
        context.insert(pair)
        try context.save()

        let opts = CompositeOptions(layout: .horizontal, jpegQuality: 0.8, watermarkEnabled: false)
        let combinedRel = try CompositeRenderer.makeComposite(
            for: pair,
            options: opts,
            storage: storage,
            in: context
        )

        XCTAssertTrue(combinedRel.hasPrefix("photos/"))
        XCTAssertTrue(combinedRel.hasSuffix(".jpg"))
        XCTAssertEqual(pair.combinedPath, combinedRel)

        let absolute = try XCTUnwrap(storage.resolve(relativePath: combinedRel))
        XCTAssertTrue(FileManager.default.fileExists(atPath: absolute.path))

        let restored = try Data(contentsOf: absolute)
        XCTAssertGreaterThan(restored.count, 0)
        // Sanity: it really is a JPEG (FFD8 SOI marker).
        XCTAssertEqual(restored[0], 0xFF)
        XCTAssertEqual(restored[1], 0xD8)
    }

    func testMakeCompositeBumpsProjectUpdatedAt() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let before = makeSolidImage(size: CGSize(width: 40, height: 40), color: .red)
        let after = makeSolidImage(size: CGSize(width: 40, height: 40), color: .green)
        let beforePath = try storage.saveBeforeJPEG(
            XCTUnwrap(before.jpegData(compressionQuality: 0.9))
        )
        let afterPath = try storage.saveAfterJPEG(
            XCTUnwrap(after.jpegData(compressionQuality: 0.9))
        )

        let project = Project(title: "T")
        // Set updatedAt to an old date so we can detect the bump.
        project.updatedAt = Date(timeIntervalSince1970: 1000)
        context.insert(project)
        let pair = PhotoPair(beforePath: beforePath, project: project)
        pair.afterPath = afterPath
        pair.status = .complete
        context.insert(pair)
        try context.save()

        let now = Date(timeIntervalSince1970: 9999)
        _ = try CompositeRenderer.makeComposite(
            for: pair,
            options: CompositeOptions(layout: .vertical, jpegQuality: 0.7, watermarkEnabled: false),
            storage: storage,
            in: context,
            now: now
        )
        XCTAssertEqual(project.updatedAt, now)
    }

    // MARK: - edge

    func testMakeCompositeThrowsWhenAfterPathMissing() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let before = makeSolidImage(size: CGSize(width: 30, height: 30), color: .gray)
        let beforePath = try storage.saveBeforeJPEG(
            XCTUnwrap(before.jpegData(compressionQuality: 0.9))
        )
        let project = Project(title: "P")
        context.insert(project)
        let pair = PhotoPair(beforePath: beforePath, project: project)
        // Intentionally leave afterPath = nil.
        context.insert(pair)
        try context.save()

        XCTAssertThrowsError(
            try CompositeRenderer.makeComposite(for: pair, storage: storage, in: context)
        ) { error in
            XCTAssertEqual(error as? CompositeRenderer.RenderError, .afterPathNotSet)
        }
    }

    func testMakeCompositeThrowsWhenBeforeFileMissing() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let after = makeSolidImage(size: CGSize(width: 30, height: 30), color: .gray)
        let afterPath = try storage.saveAfterJPEG(
            XCTUnwrap(after.jpegData(compressionQuality: 0.9))
        )
        let project = Project(title: "P")
        context.insert(project)
        // Reference a file that was never written.
        let pair = PhotoPair(
            beforePath: "photos/missing-\(UUID().uuidString).jpg",
            project: project
        )
        pair.afterPath = afterPath
        pair.status = .complete
        context.insert(pair)
        try context.save()

        XCTAssertThrowsError(
            try CompositeRenderer.makeComposite(for: pair, storage: storage, in: context)
        ) { error in
            XCTAssertEqual(error as? CompositeRenderer.RenderError, .beforeImageMissing)
        }
    }

    func testComposeFramesHandlesZeroDimensionsDefensively() {
        let frames = CompositeRenderer.composeFrames(
            beforeSize: .zero,
            afterSize: CGSize(width: 100, height: 100),
            layout: .horizontal
        )
        // Zero collapses to 1×1 internally, so canvas is well-defined and >0.
        XCTAssertGreaterThan(frames.canvas.width, 0)
        XCTAssertGreaterThan(frames.canvas.height, 0)
    }

    func testCompositeLayoutAllCasesHaveDistinctLabels() {
        XCTAssertEqual(CompositeLayout.allCases.count, 2)
        XCTAssertNotEqual(CompositeLayout.horizontal.label, CompositeLayout.vertical.label)
        XCTAssertFalse(CompositeLayout.horizontal.label.isEmpty)
        XCTAssertFalse(CompositeLayout.vertical.label.isEmpty)
    }

    // MARK: - helpers

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
}
