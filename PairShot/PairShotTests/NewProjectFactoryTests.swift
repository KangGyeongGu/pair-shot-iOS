import CoreLocation
import XCTest
@testable import PairShot

private final class StubLocationService: LocationProviding, @unchecked Sendable {
    let result: CLLocation?
    private(set) var callCount: Int = 0

    init(result: CLLocation?) {
        self.result = result
    }

    func requestSingleLocation() async -> CLLocation? {
        callCount += 1
        return result
    }
}

final class NewProjectFactoryTests: XCTestCase {
    func testMakeWithGPSPopulatesCoordinates() async {
        let stub = StubLocationService(result: CLLocation(latitude: 37.5665, longitude: 126.978))
        let project = await NewProjectFactory.make(title: "현장 A", includeGPS: true, locationService: stub)
        XCTAssertNotNil(project)
        XCTAssertEqual(project?.title, "현장 A")
        XCTAssertEqual(project?.latitude ?? .nan, 37.5665, accuracy: 0.0001)
        XCTAssertEqual(project?.longitude ?? .nan, 126.978, accuracy: 0.0001)
        XCTAssertEqual(stub.callCount, 1)
    }

    func testMakeWithoutGPSSkipsLocationRequest() async {
        let stub = StubLocationService(result: CLLocation(latitude: 1, longitude: 2))
        let project = await NewProjectFactory.make(title: "현장 B", includeGPS: false, locationService: stub)
        XCTAssertNotNil(project)
        XCTAssertNil(project?.latitude)
        XCTAssertNil(project?.longitude)
        XCTAssertEqual(stub.callCount, 0, "location service must not be called when GPS disabled")
    }

    func testMakeWithDeniedPermissionReturnsProjectWithoutLocation() async {
        let stub = StubLocationService(result: nil)
        let project = await NewProjectFactory.make(title: "권한 거부", includeGPS: true, locationService: stub)
        XCTAssertNotNil(project, "project must still be created when location is unavailable")
        XCTAssertNil(project?.latitude)
        XCTAssertNil(project?.longitude)
        XCTAssertEqual(stub.callCount, 1)
    }

    func testMakeWithEmptyTitleReturnsNil() async {
        let stub = StubLocationService(result: nil)
        let project = await NewProjectFactory.make(title: "", includeGPS: false, locationService: stub)
        XCTAssertNil(project)
    }

    func testMakeWithWhitespaceOnlyTitleReturnsNil() async {
        let stub = StubLocationService(result: nil)
        let project = await NewProjectFactory.make(title: "   \n\t ", includeGPS: false, locationService: stub)
        XCTAssertNil(project)
    }

    func testMakeTrimsTitleWhitespace() async {
        let stub = StubLocationService(result: nil)
        let project = await NewProjectFactory.make(title: "  공백 제거 테스트  ", includeGPS: false, locationService: stub)
        XCTAssertEqual(project?.title, "공백 제거 테스트")
    }

    func testMakePreservesKoreanUnicodeTitle() async {
        let stub = StubLocationService(result: nil)
        let title = "🏗️ 한국어 — 프로젝트"
        let project = await NewProjectFactory.make(title: title, includeGPS: false, locationService: stub)
        XCTAssertEqual(project?.title, title)
    }
}
