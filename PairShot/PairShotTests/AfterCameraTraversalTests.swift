import Foundation
@testable import PairShot
import SwiftData
import XCTest

@MainActor
final class AfterCameraTraversalTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    func testFirstPendingPairReturnsOldestPendingByCreatedAt() throws {
        let older = PhotoPair(beforeFileName: "old.jpg", capturedAt: Date(timeIntervalSince1970: 1000))
        let newer = PhotoPair(beforeFileName: "new.jpg", capturedAt: Date(timeIntervalSince1970: 2000))
        context.insert(older)
        context.insert(newer)
        try context.save()

        let first = AfterCameraPairLoader.firstPendingPair(in: [older, newer])
        XCTAssertEqual(first?.beforeFileName, "old.jpg")
    }

    func testPendingPairsExcludesPairsWithAfterFileName() throws {
        let pending = PhotoPair(beforeFileName: "p1.jpg")
        let alreadyCaptured = PhotoPair(beforeFileName: "p2.jpg")
        alreadyCaptured.afterFileName = "p2-after.jpg"
        context.insert(pending)
        context.insert(alreadyCaptured)
        try context.save()

        let pendingList = AfterCameraPairLoader.pendingPairs(in: [pending, alreadyCaptured])
        XCTAssertEqual(pendingList.count, 1)
        XCTAssertEqual(pendingList.first?.beforeFileName, "p1.jpg")
    }

    func testNextPendingPairSkipsTheJustCompletedPair() throws {
        let first = PhotoPair(beforeFileName: "1.jpg", capturedAt: Date(timeIntervalSince1970: 100))
        let second = PhotoPair(beforeFileName: "2.jpg", capturedAt: Date(timeIntervalSince1970: 200))
        let third = PhotoPair(beforeFileName: "3.jpg", capturedAt: Date(timeIntervalSince1970: 300))
        context.insert(first)
        context.insert(second)
        context.insert(third)
        try context.save()

        first.afterFileName = "1-after.jpg"
        try context.save()

        let next = AfterCameraPairLoader.nextPendingPair(after: first, in: [first, second, third])
        XCTAssertEqual(next?.beforeFileName, "2.jpg")
    }

    func testFirstPendingPairReturnsNilForEmptyList() {
        XCTAssertNil(AfterCameraPairLoader.firstPendingPair(in: []))
    }

    func testFirstPendingPairReturnsNilWhenAllComplete() {
        let p1 = PhotoPair(beforeFileName: "a.jpg")
        p1.afterFileName = "a-after.jpg"
        let p2 = PhotoPair(beforeFileName: "b.jpg")
        p2.afterFileName = "b-after.jpg"
        XCTAssertNil(AfterCameraPairLoader.firstPendingPair(in: [p1, p2]))
    }

    func testNextPendingPairReturnsNilWhenLastPendingJustCompleted() {
        let only = PhotoPair(beforeFileName: "only.jpg")
        only.afterFileName = "only-after.jpg"
        XCTAssertNil(AfterCameraPairLoader.nextPendingPair(after: only, in: [only]))
    }

    deinit {}
}
