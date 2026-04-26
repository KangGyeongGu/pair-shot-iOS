import Foundation
@testable import PairShot
import SwiftData
import SwiftUI
import XCTest

@MainActor
final class RootNavigationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
    }

    func testAlbumIsHashableForNavigationDestination() {
        let a = Album(name: "라우팅")
        var set: Set<Album> = []
        set.insert(a)
        XCTAssertTrue(set.contains(a))
    }

    func testPairGalleryViewInstantiatesWithoutAlbumScope() {
        let view = PairGalleryView()
        XCTAssertNil(view.albumId)
    }

    func testPairGalleryViewInstantiatesWithAlbumScope() {
        let id = UUID()
        let view = PairGalleryView(albumId: id)
        XCTAssertEqual(view.albumId, id)
    }

    func testBeforeCameraViewInstantiatesWithoutAlbum() {
        let view = BeforeCameraView()
        XCTAssertNil(view.albumId)
    }

    func testAfterCameraViewInstantiatesWithoutAlbum() {
        let view = AfterCameraView()
        XCTAssertNil(view.albumId)
    }

    func testContentViewDefaultBindingIsConstantFalse() {
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
        visible = false
        XCTAssertFalse(view.showFallbackAlert)
    }

    func testModelContainerBootstrapReportsFallbackFlag() {
        let result = ModelContainerBootstrap.bootstrap()
        XCTAssertNotNil(result.container)
        let second = ModelContainerBootstrap.bootstrap()
        XCTAssertEqual(result.fallbackActive, second.fallbackActive)
    }

    deinit {}
}
