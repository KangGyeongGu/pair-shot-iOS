import Foundation
@testable import PairShot
import SwiftData
import XCTest

@MainActor
final class AfterCaptureActionTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("after-capture-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testSaveAfterJPEGProducesFileNameAndPersistsBytes() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let bytes = Data(repeating: 0xCD, count: 512)
        let id = UUID()
        let name = FileNameBuilder.after(prefix: "", timestamp: .now, pairId: id)
        let returned = try storage.saveAfterJPEG(bytes, fileName: name)

        XCTAssertEqual(returned, name)
        XCTAssertTrue(returned.hasSuffix(".jpg"))

        let absolute = try XCTUnwrap(storage.resolve(kind: .after, fileName: returned))
        let restored = try Data(contentsOf: absolute)
        XCTAssertEqual(restored, bytes)
    }

    func testApplyingAfterTransitionsPairAndUpdatesAlbums() throws {
        let album = Album(name: "현장 D")
        context.insert(album)
        let pair = PhotoPair(beforeFileName: "before_test.jpg")
        pair.albums.append(album)
        context.insert(pair)
        try context.save()

        let now = Date(timeIntervalSince1970: 5000)
        let albumUpdatedBefore = album.updatedAt

        pair.afterFileName = "after_test.jpg"
        pair.afterCapturedAt = now
        pair.updatedAt = .now
        for album in pair.albums {
            album.updatedAt = .now
        }
        try context.save()

        XCTAssertEqual(pair.status, .captured)
        XCTAssertEqual(pair.afterFileName, "after_test.jpg")
        XCTAssertEqual(pair.afterCapturedAt, now)
        XCTAssertGreaterThanOrEqual(album.updatedAt, albumUpdatedBefore)
    }

    func testCoordinatorRejectsAlreadyCompletePair() async throws {
        let pair = PhotoPair(beforeFileName: "x.jpg")
        pair.afterFileName = "x-after.jpg"
        pair.afterCapturedAt = .now
        context.insert(pair)
        try context.save()

        let coordinator = AfterCaptureCoordinator(
            session: CameraSession(),
            storage: PhotoStorageService(baseDirectory: tempDir)
        )

        do {
            _ = try await coordinator.captureAfter(for: pair, into: context)
            XCTFail("captureAfter must reject an already-complete pair before touching the camera")
        } catch let AfterCaptureActionError.alreadyComplete {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNextPendingPairLogicReturnsTheFollowingOldestPending() throws {
        let p1 = PhotoPair(beforeFileName: "1.jpg", capturedAt: Date(timeIntervalSince1970: 100))
        let p2 = PhotoPair(beforeFileName: "2.jpg", capturedAt: Date(timeIntervalSince1970: 200))
        let p3 = PhotoPair(beforeFileName: "3.jpg", capturedAt: Date(timeIntervalSince1970: 300))
        context.insert(p1)
        context.insert(p2)
        context.insert(p3)
        try context.save()

        p1.afterFileName = "1-after.jpg"
        try context.save()

        let next = AfterCameraPairLoader.nextPendingPair(after: p1, in: [p1, p2, p3])
        XCTAssertEqual(next?.beforeFileName, "2.jpg")

        p2.afterFileName = "2-after.jpg"
        try context.save()
        XCTAssertEqual(
            AfterCameraPairLoader.nextPendingPair(after: p2, in: [p1, p2, p3])?.beforeFileName,
            "3.jpg"
        )
    }

    func testNextPendingPairIsNilWhenNoMoreRemain() throws {
        let only = PhotoPair(beforeFileName: "only.jpg")
        context.insert(only)
        try context.save()
        only.afterFileName = "only-after.jpg"
        try context.save()
        XCTAssertNil(AfterCameraPairLoader.nextPendingPair(after: only, in: [only]))
    }

    deinit {}
}
