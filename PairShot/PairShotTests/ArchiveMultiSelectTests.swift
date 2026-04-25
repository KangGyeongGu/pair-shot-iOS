import SwiftData
import XCTest
@testable import PairShot

@MainActor
final class ArchiveMultiSelectTests: XCTestCase {
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

    func testProjectSelectionTogglesIds() {
        let s = ProjectSelection()
        let id1 = UUID()
        let id2 = UUID()
        s.toggle(id1)
        XCTAssertTrue(s.contains(id1))
        XCTAssertEqual(s.count, 1)
        s.toggle(id2)
        XCTAssertEqual(s.count, 2)
        s.toggle(id1)
        XCTAssertFalse(s.contains(id1))
        XCTAssertEqual(s.count, 1)
    }

    func testProjectSelectionEnterAndExit() {
        let s = ProjectSelection()
        let id = UUID()
        XCTAssertFalse(s.isSelectionMode)
        s.enterSelection(with: id)
        XCTAssertTrue(s.isSelectionMode)
        XCTAssertEqual(s.selectedIds, [id])
        s.exit()
        XCTAssertFalse(s.isSelectionMode)
        XCTAssertTrue(s.selectedIds.isEmpty)
    }

    func testDeleteProjectsCascadesToPairs() throws {
        let p1 = Project(title: "삭제대상-1")
        let p2 = Project(title: "삭제대상-2")
        let p3 = Project(title: "유지")
        context.insert(p1)
        context.insert(p2)
        context.insert(p3)
        let pairs1 = (0 ..< 2).map { i in
            PhotoPair(beforePath: "p1-\(i).jpg", project: p1)
        }
        let pairs2 = (0 ..< 3).map { i in
            PhotoPair(beforePath: "p2-\(i).jpg", project: p2)
        }
        let pairs3 = [PhotoPair(beforePath: "p3-0.jpg", project: p3)]
        for pair in pairs1 + pairs2 + pairs3 {
            context.insert(pair)
        }
        try context.save()

        let beforePairs = try context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertEqual(beforePairs.count, 6)

        let removedCount = try ProjectDeletionService.deleteProjects(
            ids: [p1.id, p2.id],
            in: context
        )
        XCTAssertEqual(removedCount, 2)

        let remainingProjects = try context.fetch(FetchDescriptor<Project>())
        XCTAssertEqual(remainingProjects.map(\.title), ["유지"])

        let remainingPairs = try context.fetch(FetchDescriptor<PhotoPair>())
        XCTAssertEqual(remainingPairs.count, 1)
        XCTAssertEqual(remainingPairs.first?.beforePath, "p3-0.jpg")
    }

    func testDeleteProjectsWithEmptySetIsNoOp() throws {
        let p1 = Project(title: "유지")
        context.insert(p1)
        try context.save()

        let removed = try ProjectDeletionService.deleteProjects(ids: [], in: context)
        XCTAssertEqual(removed, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Project>()).count, 1)
    }

    func testDeleteProjectsWithUnknownIdRemovesNothing() throws {
        let p1 = Project(title: "유지")
        context.insert(p1)
        try context.save()

        let removed = try ProjectDeletionService.deleteProjects(ids: [UUID()], in: context)
        XCTAssertEqual(removed, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Project>()).count, 1)
    }

    func testRenameUpdatesTitleAndUpdatedAt() throws {
        let project = Project(title: "원래", createdAt: Date(timeIntervalSince1970: 1_000))
        project.updatedAt = Date(timeIntervalSince1970: 1_000)
        context.insert(project)
        try context.save()

        ProjectRenameService.rename(project, to: "새 이름", in: context)

        XCTAssertEqual(project.title, "새 이름")
        XCTAssertGreaterThan(project.updatedAt.timeIntervalSince1970, 1_000)
    }

    func testRenameTrimsAndIgnoresEmpty() throws {
        let project = Project(title: "기본")
        context.insert(project)
        try context.save()

        ProjectRenameService.rename(project, to: "  공백 트림 테스트  ", in: context)
        XCTAssertEqual(project.title, "공백 트림 테스트")

        ProjectRenameService.rename(project, to: "   ", in: context)
        XCTAssertEqual(project.title, "공백 트림 테스트", "empty after trim must be ignored")
    }

    func testRenameNoOpWhenSameTitle() throws {
        let original = Date(timeIntervalSince1970: 5_000)
        let project = Project(title: "동일", createdAt: original)
        project.updatedAt = original
        context.insert(project)
        try context.save()

        ProjectRenameService.rename(project, to: "동일", in: context)
        XCTAssertEqual(project.updatedAt, original, "same title must not bump updatedAt")
    }
}
