import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P3.4 — Capture → COMPLETE transition + cascade to next pendingAfter.
///
/// We exercise the SwiftData-side state changes plus storage.saveAfterJPEG
/// directly (camera capture itself can't run on the iOS simulator without a
/// device — that's covered manually in P9). The coordinator's `alreadyComplete`
/// guard is also asserted.
@MainActor
final class AfterCaptureActionTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([Project.self, PhotoPair.self])
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

    // MARK: - happy

    func testSaveAfterJPEGProducesRelativePathAndPersistsBytes() throws {
        let storage = PhotoStorageService(baseDirectory: tempDir)
        let bytes = Data(repeating: 0xCD, count: 512)
        let id = UUID()

        let relative = try storage.saveAfterJPEG(bytes, fileID: id)

        XCTAssertTrue(relative.hasPrefix("photos/"))
        XCTAssertTrue(relative.hasSuffix(".jpg"))
        XCTAssertTrue(relative.contains(id.uuidString))

        let absolute = try XCTUnwrap(storage.resolve(relativePath: relative))
        let restored = try Data(contentsOf: absolute)
        XCTAssertEqual(restored, bytes)
    }

    func testApplyingAfterTransitionsPairToCompleteAndUpdatesProject() throws {
        let project = Project(title: "현장 D")
        context.insert(project)

        let pair = PhotoPair(beforePath: "photos/before.jpg", project: project)
        context.insert(pair)
        try context.save()

        // Hand-roll the same field mutations the coordinator performs. We can't
        // run the actor capture here, so we assert the *transition* shape.
        let now = Date(timeIntervalSince1970: 5000)
        let before = project.updatedAt

        pair.afterPath = "photos/after.jpg"
        pair.afterCapturedAt = now
        pair.status = .complete
        pair.project?.updatedAt = .now
        try context.save()

        XCTAssertEqual(pair.status, .complete)
        XCTAssertEqual(pair.afterPath, "photos/after.jpg")
        XCTAssertEqual(pair.afterCapturedAt, now)
        XCTAssertGreaterThanOrEqual(project.updatedAt, before)
    }

    func testCoordinatorRejectsAlreadyCompletePair() async throws {
        let project = Project(title: "현장 E")
        context.insert(project)

        let pair = PhotoPair(beforePath: "photos/x.jpg", project: project)
        pair.status = .complete
        pair.afterPath = "photos/x-after.jpg"
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

    // MARK: - edge

    func testOutcomeNextPendingPairIsTheFollowingOldestPending() throws {
        let project = Project(title: "현장 F")
        context.insert(project)

        let p1 = PhotoPair(
            beforePath: "photos/1.jpg",
            capturedAt: Date(timeIntervalSince1970: 100),
            project: project
        )
        let p2 = PhotoPair(
            beforePath: "photos/2.jpg",
            capturedAt: Date(timeIntervalSince1970: 200),
            project: project
        )
        let p3 = PhotoPair(
            beforePath: "photos/3.jpg",
            capturedAt: Date(timeIntervalSince1970: 300),
            project: project
        )
        context.insert(p1)
        context.insert(p2)
        context.insert(p3)
        try context.save()

        // Simulate p1 was just captured — outcome.nextPendingPair should be p2.
        p1.status = .complete
        p1.afterPath = "photos/1-after.jpg"
        try context.save()

        let next = AfterCameraPairLoader.nextPendingPair(after: p1)
        XCTAssertEqual(next?.beforePath, "photos/2.jpg")

        // Then capture p2 → next should be p3.
        p2.status = .complete
        p2.afterPath = "photos/2-after.jpg"
        try context.save()
        XCTAssertEqual(AfterCameraPairLoader.nextPendingPair(after: p2)?.beforePath, "photos/3.jpg")
    }

    func testOutcomeNextPendingPairIsNilWhenNoMoreRemain() throws {
        let project = Project(title: "현장 G")
        context.insert(project)

        let only = PhotoPair(beforePath: "photos/only.jpg", project: project)
        context.insert(only)
        try context.save()

        only.status = .complete
        only.afterPath = "photos/only-after.jpg"
        try context.save()

        XCTAssertNil(AfterCameraPairLoader.nextPendingPair(after: only))
    }

    func testCoordinatorRejectsPairWithExistingAfterPathEvenIfStatusStillPending() async throws {
        // Defensive: status not yet flipped to .complete but afterPath already
        // set (interrupted previous capture). Coordinator should still bail.
        let project = Project(title: "중복 방지")
        context.insert(project)

        let pair = PhotoPair(beforePath: "photos/y.jpg", project: project)
        pair.afterPath = "photos/y-after.jpg" // status still .pendingAfter
        context.insert(pair)
        try context.save()

        let coordinator = AfterCaptureCoordinator(
            session: CameraSession(),
            storage: PhotoStorageService(baseDirectory: tempDir)
        )

        do {
            _ = try await coordinator.captureAfter(for: pair, into: context)
            XCTFail("Coordinator must guard against double-capture even mid-state")
        } catch AfterCaptureActionError.alreadyComplete {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    deinit {}
}
