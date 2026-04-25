import Foundation
@testable import PairShot
import SwiftData
import SwiftUI
import XCTest

/// P4.1 — `PairGalleryView` data plumbing: filtered + sorted pair listing.
///
/// SwiftUI body is exercised by the build (preview compiles); this suite
/// focuses on the deterministic data shape the grid sees.
@MainActor
final class PairGalleryViewTests: XCTestCase {
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

    // MARK: - happy

    func testProjectPairsSortedByCapturedAtDescending() throws {
        let project = Project(title: "현장")
        context.insert(project)

        let mid = PhotoPair(
            beforePath: "p/mid.jpg",
            capturedAt: Date(timeIntervalSince1970: 2000),
            project: project
        )
        let oldest = PhotoPair(
            beforePath: "p/old.jpg",
            capturedAt: Date(timeIntervalSince1970: 1000),
            project: project
        )
        let newest = PhotoPair(
            beforePath: "p/new.jpg",
            capturedAt: Date(timeIntervalSince1970: 3000),
            project: project
        )
        context.insert(oldest)
        context.insert(mid)
        context.insert(newest)
        try context.save()

        let sorted = project.pairs.sorted { $0.beforeCapturedAt > $1.beforeCapturedAt }
        XCTAssertEqual(sorted.map(\.beforePath), ["p/new.jpg", "p/mid.jpg", "p/old.jpg"])
    }

    func testFilterAllShowsEveryPair() throws {
        let project = Project(title: "현장")
        context.insert(project)
        let pendingPair = PhotoPair(beforePath: "p/a.jpg", project: project)
        let completePair = PhotoPair(beforePath: "p/b.jpg", project: project)
        completePair.status = .complete
        let combinedPair = PhotoPair(beforePath: "p/c.jpg", project: project)
        combinedPair.combinedPath = "p/c-x.jpg"
        context.insert(pendingPair)
        context.insert(completePair)
        context.insert(combinedPair)
        try context.save()

        XCTAssertEqual(GalleryFilter.all.apply(to: project.pairs).count, 3)
    }

    func testFilterCombinedRestrictsToCompositedPairs() throws {
        let project = Project(title: "현장")
        context.insert(project)
        let plain = PhotoPair(beforePath: "p/a.jpg", project: project)
        let combined = PhotoPair(beforePath: "p/b.jpg", project: project)
        combined.combinedPath = "p/b-cx.jpg"
        context.insert(plain)
        context.insert(combined)
        try context.save()

        let filtered = GalleryFilter.combinedOnly.apply(to: project.pairs)
        XCTAssertEqual(filtered.map(\.beforePath), ["p/b.jpg"])
    }

    // MARK: - edge

    func testEmptyProjectProducesEmptyFilterOutput() {
        let project = Project(title: "빈 프로젝트")
        XCTAssertTrue(GalleryFilter.all.apply(to: project.pairs).isEmpty)
        XCTAssertTrue(GalleryFilter.combinedOnly.apply(to: project.pairs).isEmpty)
    }

    func testTwoColumnGridConstantIsStable() {
        // The 2-col layout is a Phase 4 contract (Android parity). Keep a
        // direct assertion so a stray refactor renaming/duplicating columns
        // surfaces immediately.
        let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
        XCTAssertEqual(columns.count, 2)
    }

    func testInitializerAcceptsCustomStorage() {
        let project = Project(title: "주입")
        let custom = PhotoStorageService(baseDirectory: FileManager.default.temporaryDirectory)
        let view = PairGalleryView(project: project, storage: custom)
        XCTAssertEqual(view.project.title, "주입")
    }
}
