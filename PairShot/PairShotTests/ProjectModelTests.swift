@testable import PairShot
import SwiftData
import XCTest

@MainActor
final class ProjectModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
    }

    func testProjectInitDefaults() throws {
        let project = Project(title: "현장-A")
        context.insert(project)
        try context.save()

        XCTAssertFalse(project.id.uuidString.isEmpty)
        XCTAssertEqual(project.title, "현장-A")
        XCTAssertEqual(project.createdAt, project.updatedAt)
        XCTAssertNil(project.latitude)
        XCTAssertNil(project.longitude)
        XCTAssertNil(project.locationLabel)
        XCTAssertTrue(project.pairs.isEmpty)
    }

    func testProjectInitWithGPS() throws {
        let project = Project(
            title: "GPS 현장",
            latitude: 37.5665,
            longitude: 126.978,
            locationLabel: "서울시 중구"
        )
        context.insert(project)
        try context.save()

        XCTAssertEqual(project.latitude, 37.5665)
        XCTAssertEqual(project.longitude, 126.978)
        XCTAssertEqual(project.locationLabel, "서울시 중구")
    }

    func testProjectIdsAreUnique() {
        let p1 = Project(title: "A")
        let p2 = Project(title: "B")
        XCTAssertNotEqual(p1.id, p2.id)
    }

    func testCascadeDeleteRemovesPairs() throws {
        let project = Project(title: "삭제테스트")
        context.insert(project)
        let pair = PhotoPair(beforePath: "before-001.jpg", project: project)
        context.insert(pair)
        try context.save()

        XCTAssertEqual(project.pairs.count, 1)

        context.delete(project)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertTrue(remaining.isEmpty, "Cascade delete must remove orphaned PhotoPair")
    }

    func testKoreanUnicodeTitlePreserved() throws {
        let title = "🏗️ 한국어 제목 — 테스트"
        let project = Project(title: title)
        context.insert(project)
        try context.save()
        XCTAssertEqual(project.title, title)
    }

    func testEmptyTitleIsAllowed() throws {
        let project = Project(title: "")
        context.insert(project)
        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(project.title, "")
    }

    func testPhotoPairDefaultStatusIsPending() {
        let pair = PhotoPair(beforePath: "x.jpg")
        XCTAssertEqual(pair.status, .pendingAfter)
        XCTAssertNil(pair.afterPath)
        XCTAssertNil(pair.combinedPath)
        XCTAssertNil(pair.afterCapturedAt)
    }
}
