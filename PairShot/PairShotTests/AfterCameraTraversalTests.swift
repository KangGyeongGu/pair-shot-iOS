import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P3.1 — auto-traversal: load oldest pendingAfter pair on entry, advance to
/// the next on capture completion, dismiss when none remain.
@MainActor
final class AfterCameraTraversalTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - happy

    func testFirstPendingPairReturnsOldestPendingByBeforeCapturedAt() throws {
        let project = Project(title: "현장 A")
        context.insert(project)

        let older = PhotoPair(
            beforePath: "photos/old.jpg",
            capturedAt: Date(timeIntervalSince1970: 1000),
            project: project
        )
        let newer = PhotoPair(
            beforePath: "photos/new.jpg",
            capturedAt: Date(timeIntervalSince1970: 2000),
            project: project
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let first = AfterCameraPairLoader.firstPendingPair(in: project)
        XCTAssertEqual(first?.beforePath, "photos/old.jpg")
    }

    func testPendingPairsExcludesCompletedAndPairsWithAfterPath() throws {
        let project = Project(title: "현장 B")
        context.insert(project)

        let pending = PhotoPair(beforePath: "photos/p1.jpg", project: project)
        let alreadyCaptured = PhotoPair(beforePath: "photos/p2.jpg", project: project)
        alreadyCaptured.afterPath = "photos/p2-after.jpg"
        let complete = PhotoPair(beforePath: "photos/p3.jpg", project: project)
        complete.status = .complete
        complete.afterPath = "photos/p3-after.jpg"
        complete.afterCapturedAt = .now

        context.insert(pending)
        context.insert(alreadyCaptured)
        context.insert(complete)
        try context.save()

        let pendingList = AfterCameraPairLoader.pendingPairs(in: project)
        XCTAssertEqual(pendingList.count, 1)
        XCTAssertEqual(pendingList.first?.beforePath, "photos/p1.jpg")
    }

    func testNextPendingPairSkipsTheJustCompletedPair() throws {
        let project = Project(title: "현장 C")
        context.insert(project)

        let first = PhotoPair(
            beforePath: "photos/1.jpg",
            capturedAt: Date(timeIntervalSince1970: 100),
            project: project
        )
        let second = PhotoPair(
            beforePath: "photos/2.jpg",
            capturedAt: Date(timeIntervalSince1970: 200),
            project: project
        )
        let third = PhotoPair(
            beforePath: "photos/3.jpg",
            capturedAt: Date(timeIntervalSince1970: 300),
            project: project
        )
        context.insert(first)
        context.insert(second)
        context.insert(third)
        try context.save()

        // Simulate first being just completed.
        first.status = .complete
        first.afterPath = "photos/1-after.jpg"
        try context.save()

        let next = AfterCameraPairLoader.nextPendingPair(after: first)
        XCTAssertEqual(next?.beforePath, "photos/2.jpg")
    }

    // MARK: - edge

    func testFirstPendingPairReturnsNilForEmptyProject() {
        let project = Project(title: "빈 프로젝트")
        XCTAssertNil(AfterCameraPairLoader.firstPendingPair(in: project))
    }

    func testFirstPendingPairReturnsNilWhenAllComplete() throws {
        let project = Project(title: "완료된 프로젝트")
        context.insert(project)

        let p1 = PhotoPair(beforePath: "photos/a.jpg", project: project)
        p1.status = .complete
        p1.afterPath = "photos/a-after.jpg"
        let p2 = PhotoPair(beforePath: "photos/b.jpg", project: project)
        p2.status = .complete
        p2.afterPath = "photos/b-after.jpg"
        context.insert(p1)
        context.insert(p2)
        try context.save()

        XCTAssertNil(AfterCameraPairLoader.firstPendingPair(in: project))
    }

    func testNextPendingPairReturnsNilWhenLastPendingJustCompleted() throws {
        let project = Project(title: "마지막 완료")
        context.insert(project)

        let only = PhotoPair(beforePath: "photos/only.jpg", project: project)
        context.insert(only)
        try context.save()

        only.status = .complete
        only.afterPath = "photos/only-after.jpg"
        try context.save()

        XCTAssertNil(AfterCameraPairLoader.nextPendingPair(after: only))
    }

    func testNextPendingPairReturnsNilWhenPairHasNoProject() {
        let orphan = PhotoPair(beforePath: "photos/orphan.jpg")
        XCTAssertNil(AfterCameraPairLoader.nextPendingPair(after: orphan))
    }

    deinit {}
}
