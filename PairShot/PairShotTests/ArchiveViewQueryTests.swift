import SwiftData
import XCTest
@testable import PairShot

@MainActor
final class ArchiveViewQueryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        let schema = Schema([Project.self, PhotoPair.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
    }

    func testEmptyContextHasNoProjects() throws {
        let result = try context.fetch(FetchDescriptor<Project>())
        XCTAssertTrue(result.isEmpty)
    }

    func testSortByUpdatedAtDescending() throws {
        let p1 = Project(title: "A", createdAt: Date(timeIntervalSince1970: 1_000))
        let p2 = Project(title: "B", createdAt: Date(timeIntervalSince1970: 3_000))
        let p3 = Project(title: "C", createdAt: Date(timeIntervalSince1970: 2_000))
        p1.updatedAt = Date(timeIntervalSince1970: 5_000)
        p2.updatedAt = Date(timeIntervalSince1970: 4_000)
        p3.updatedAt = Date(timeIntervalSince1970: 3_500)
        context.insert(p1)
        context.insert(p2)
        context.insert(p3)
        try context.save()

        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let result = try context.fetch(descriptor)
        XCTAssertEqual(result.map(\.title), ["A", "B", "C"])
    }

    func testSortByCreatedAtDescending() throws {
        let p1 = Project(title: "1", createdAt: Date(timeIntervalSince1970: 1_000))
        let p2 = Project(title: "2", createdAt: Date(timeIntervalSince1970: 3_000))
        let p3 = Project(title: "3", createdAt: Date(timeIntervalSince1970: 2_000))
        context.insert(p1)
        context.insert(p2)
        context.insert(p3)
        try context.save()

        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let result = try context.fetch(descriptor)
        XCTAssertEqual(result.map(\.title), ["2", "3", "1"])
    }

    func testBadgeCountsAcrossPairStatuses() throws {
        let project = Project(title: "배지 테스트")
        context.insert(project)
        let pair1 = PhotoPair(beforePath: "1.jpg", project: project)
        pair1.status = .complete
        let pair2 = PhotoPair(beforePath: "2.jpg", project: project)
        pair2.status = .complete
        pair2.combinedPath = "1+2.jpg"
        let pair3 = PhotoPair(beforePath: "3.jpg", project: project)
        context.insert(pair1)
        context.insert(pair2)
        context.insert(pair3)
        try context.save()

        XCTAssertEqual(project.pairs.count, 3)
        let completed = project.pairs.filter { $0.status == .complete }.count
        let combined = project.pairs.filter { $0.combinedPath != nil }.count
        XCTAssertEqual(completed, 2)
        XCTAssertEqual(combined, 1)
    }

    func testArchiveSortOptionLabelsAreKorean() {
        XCTAssertEqual(ArchiveSortOption.updatedAtDesc.label, "최근 수정")
        XCTAssertEqual(ArchiveSortOption.createdAtDesc.label, "생성일")
    }
}
