import AppTrackingTransparency
import Foundation
@testable import PairShot
import XCTest

/// Audit-B — `AdRequestBuilder.shouldAttachNonPersonalised(attStatus:)`
/// is the pure tracking-status policy every ad surface consults
/// before constructing a `GADRequest`.
///
/// Why this matters:
/// - `.authorized` is the ONLY status that lets the SDK use the IDFA
///   for personalised ads. Anything else (denied / restricted /
///   notDetermined) must carry the `npa=1` extra so served ads fall
///   back to non-personalised inventory.
/// - Forgetting the npa signal on even one surface is a privacy
///   compliance hole. This test pins the matrix so a refactor that
///   inverts a check fails immediately.
final class AdRequestBuilderTests: XCTestCase {
    func testAuthorizedDoesNotAttachNonPersonalised() {
        XCTAssertFalse(
            AdRequestBuilder.shouldAttachNonPersonalised(attStatus: .authorized),
            ".authorized is the only status that permits personalised ads"
        )
    }

    func testDeniedAttachesNonPersonalised() {
        XCTAssertTrue(
            AdRequestBuilder.shouldAttachNonPersonalised(attStatus: .denied),
            ".denied must carry npa=1 so the SDK serves non-personalised ads"
        )
    }

    func testRestrictedAttachesNonPersonalised() {
        XCTAssertTrue(
            AdRequestBuilder.shouldAttachNonPersonalised(attStatus: .restricted),
            ".restricted (parental controls / device policy) must carry npa=1"
        )
    }

    func testNotDeterminedAttachesNonPersonalised() {
        XCTAssertTrue(
            AdRequestBuilder.shouldAttachNonPersonalised(attStatus: .notDetermined),
            ".notDetermined must carry npa=1 — the SDK should never personalise before the user has decided"
        )
    }
}
