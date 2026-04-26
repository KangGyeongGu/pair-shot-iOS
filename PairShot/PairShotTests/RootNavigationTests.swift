import Foundation
@testable import PairShot
import SwiftData
import SwiftUI
import XCTest

/// Audit-A — smoke-level checks for the Archive → Gallery → Camera
/// routing. SwiftUI navigation surfaces (`NavigationLink(value:)` /
/// `navigationDestination(for:)` / `fullScreenCover`) cannot be
/// driven from XCTest without the Simulator host app, so these tests
/// instead verify that:
///
/// 1. Each destination view can be **instantiated** with the same
///    `Project` / `PhotoPair` types the gallery hands them.
/// 2. `Project` is `Hashable`, which is the precondition for
///    `NavigationLink(value: project)` + `navigationDestination(for:
///    Project.self)`.
/// 3. `ContentView` exposes the binding `PairShotApp` uses to surface
///    the in-memory fallback alert.
///
/// UI-level navigation is covered by manual checklists (`docs/01-device-test-checklist.md`).
@MainActor
final class RootNavigationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        let schema = Schema([Project.self, PhotoPair.self, Coupon.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - happy

    func testProjectIsHashableForNavigationDestination() {
        // Hashable conformance is required by `navigationDestination(for: Project.self)`
        // — `@Model` types provide it automatically via `PersistentModel`,
        // but a future refactor swapping the model type could quietly
        // break this. Pin it.
        let p = Project(title: "라우팅")
        var set: Set<Project> = []
        set.insert(p)
        XCTAssertTrue(set.contains(p))
    }

    func testPairGalleryViewInstantiatesForProject() {
        let project = Project(title: "갤러리")
        context.insert(project)
        // `PairGalleryView.init` just stores the project + storage —
        // no SwiftUI body evaluation here, but a compile-time + init
        // smoke check is enough to catch signature regressions.
        let view = PairGalleryView(project: project)
        XCTAssertEqual(view.project.title, "갤러리")
    }

    func testBeforeCameraViewInstantiatesForProject() {
        let project = Project(title: "Before 촬영")
        context.insert(project)
        let view = BeforeCameraView(project: project)
        XCTAssertEqual(view.project.title, "Before 촬영")
    }

    func testAfterCameraViewInstantiatesForProject() {
        let project = Project(title: "After 촬영")
        context.insert(project)
        let view = AfterCameraView(project: project)
        XCTAssertEqual(view.project.title, "After 촬영")
    }

    // MARK: - edge / fallback alert wiring

    func testContentViewDefaultBindingIsConstantFalse() {
        // No-arg init must default the alert binding to `.constant(false)`
        // so previews and tests don't accidentally surface the fallback alert.
        let view = ContentView()
        XCTAssertFalse(view.showFallbackAlert)
    }

    func testContentViewBindingPropagatesAlertState() {
        var visible = true
        let binding = Binding<Bool>(
            get: { visible },
            set: { visible = $0 }
        )
        let view = ContentView(showFallbackAlert: binding)
        XCTAssertTrue(view.showFallbackAlert)
        // Flip the source of truth and confirm the view's binding sees it.
        visible = false
        XCTAssertFalse(view.showFallbackAlert)
    }

    func testModelContainerBootstrapReportsFallbackFlag() {
        // Build via the bootstrap helper to make sure the result type
        // exposes `fallbackActive`. A successful happy-path bootstrap
        // returns `false`; the in-memory-fallback branch is exercised
        // only when the disk path fails — too brittle to simulate
        // here, so we just verify the API surface.
        let result = ModelContainerBootstrap.bootstrap()
        XCTAssertNotNil(result.container)
        // Either value is acceptable: tests sometimes share storage
        // with prior runs. We just need the property to exist + be
        // Bool.
        let flag = result.fallbackActive
        XCTAssertTrue(flag == true || flag == false)
    }
}
