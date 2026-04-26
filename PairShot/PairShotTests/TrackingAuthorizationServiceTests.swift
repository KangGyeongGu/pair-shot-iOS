import AppTrackingTransparency
import Foundation
@testable import PairShot
import XCTest

/// P6.2 — `TrackingAuthorizationService` wraps `ATTrackingManager` and
/// exposes a single `requestIfUndetermined()` entry point. Tests use a
/// `FakeProvider` to drive deterministic state since the system framework
/// can only prompt from a real foreground app.
@MainActor
final class TrackingAuthorizationServiceTests: XCTestCase {
    /// In-memory fake of `TrackingAuthorizationProviding` whose
    /// `currentStatus` and async response are caller-controlled.
    private final class FakeProvider: TrackingAuthorizationProviding, @unchecked Sendable {
        var status: ATTrackingManager.AuthorizationStatus
        var responseStatus: ATTrackingManager.AuthorizationStatus
        private(set) var requestCallCount = 0

        init(
            status: ATTrackingManager.AuthorizationStatus,
            responseStatus: ATTrackingManager.AuthorizationStatus? = nil
        ) {
            self.status = status
            self.responseStatus = responseStatus ?? status
        }

        var currentStatus: ATTrackingManager.AuthorizationStatus { status }

        func requestAuthorization() async -> ATTrackingManager.AuthorizationStatus {
            requestCallCount += 1
            status = responseStatus
            return responseStatus
        }
    }

    // MARK: - happy

    func testInitialStatusMirrorsProvider() {
        let fake = FakeProvider(status: .authorized)
        let service = TrackingAuthorizationService(provider: fake)
        XCTAssertEqual(service.currentStatus, .authorized)
        XCTAssertTrue(service.isAuthorized)
    }

    func testRequestIfUndeterminedPromptsUserAndUpdatesStatus() async {
        let fake = FakeProvider(status: .notDetermined, responseStatus: .authorized)
        let service = TrackingAuthorizationService(provider: fake)
        XCTAssertEqual(service.currentStatus, .notDetermined)

        let result = await service.requestIfUndetermined()
        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(service.currentStatus, .authorized)
        XCTAssertTrue(service.isAuthorized)
        XCTAssertEqual(fake.requestCallCount, 1)
    }

    // MARK: - edge

    func testRequestIfUndeterminedReturnsImmediatelyWhenAlreadyAuthorized() async {
        let fake = FakeProvider(status: .authorized)
        let service = TrackingAuthorizationService(provider: fake)

        let result = await service.requestIfUndetermined()
        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(fake.requestCallCount, 0, "should not prompt when already decided")
    }

    func testRequestIfUndeterminedReturnsImmediatelyWhenDenied() async {
        let fake = FakeProvider(status: .denied)
        let service = TrackingAuthorizationService(provider: fake)

        let result = await service.requestIfUndetermined()
        XCTAssertEqual(result, .denied)
        XCTAssertFalse(service.isAuthorized)
        XCTAssertEqual(fake.requestCallCount, 0)
    }

    func testRequestIfUndeterminedReturnsImmediatelyWhenRestricted() async {
        let fake = FakeProvider(status: .restricted)
        let service = TrackingAuthorizationService(provider: fake)

        let result = await service.requestIfUndetermined()
        XCTAssertEqual(result, .restricted)
        XCTAssertEqual(fake.requestCallCount, 0)
    }

    func testRefreshPicksUpExternalChange() {
        let fake = FakeProvider(status: .notDetermined)
        let service = TrackingAuthorizationService(provider: fake)
        XCTAssertEqual(service.currentStatus, .notDetermined)

        // User toggled the toggle in Settings while the app was suspended.
        fake.status = .denied
        service.refresh()
        XCTAssertEqual(service.currentStatus, .denied)
    }

    func testDeniedDecisionIsPersistedAfterRequest() async {
        let fake = FakeProvider(status: .notDetermined, responseStatus: .denied)
        let service = TrackingAuthorizationService(provider: fake)

        let result = await service.requestIfUndetermined()
        XCTAssertEqual(result, .denied)
        XCTAssertFalse(service.isAuthorized)
        XCTAssertEqual(service.currentStatus, .denied)
    }

    func testSystemProviderInitialStatusMatchesATTrackingManager() {
        let provider = SystemTrackingAuthorizationProvider()
        XCTAssertEqual(
            provider.currentStatus,
            ATTrackingManager.trackingAuthorizationStatus
        )
    }
}
