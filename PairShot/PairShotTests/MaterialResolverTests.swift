import Foundation
@testable import PairShot
import SwiftUI
import XCTest

/// P9.2 — `AppMaterial` token resolution.
///
/// The `if #available(iOS 26.0, *)` Liquid Glass branch can't be
/// directly verified (XCTest runs against the same OS the
/// implementation guards on), but we *can* assert:
///
/// 1. Every `AppMaterial` case produces a non-nil `Material` on the
///    iOS-17 fallback path (the path the production binary actually
///    reaches today on the simulator).
/// 2. The `identifier` round-trip is exhaustive — adding a new case
///    without an `identifier` mapping will fail here.
/// 3. `AppMaterial.allCases` covers every identifier the rest of the
///    app uses so token additions don't drift silently.
@MainActor
final class MaterialResolverTests: XCTestCase {
    // MARK: - Mapping completeness

    func testEveryCaseResolvesToAMaterial() {
        // We can't compare `Material` values for equality (the type
        // doesn't conform to Equatable), but we can verify the
        // resolver doesn't trap and that the identifier is stable.
        for token in AppMaterial.allCases {
            let identifier = token.identifier
            XCTAssertFalse(identifier.isEmpty, "identifier missing for \(token)")
            // Force the resolution path; a missing case in the
            // switch would crash here.
            _ = token.swiftUIMaterial
        }
    }

    // MARK: - Identifier round-trip

    func testIdentifierRoundTripCoversAllCases() {
        for token in AppMaterial.allCases {
            let restored = AppMaterial(identifier: token.identifier)
            XCTAssertEqual(restored, token, "identifier round-trip failed for \(token)")
        }
    }

    func testUnknownIdentifierReturnsNil() {
        XCTAssertNil(AppMaterial(identifier: "definitely-not-a-token"))
        XCTAssertNil(AppMaterial(identifier: ""))
    }

    // MARK: - Token surface

    func testKnownIdentifiersStaySupported() {
        // Lock the public token surface so a renaming PR breaks here
        // before it breaks the call sites.
        let identifiers = Set(AppMaterial.allCases.map(\.identifier))
        XCTAssertEqual(identifiers, ["panel", "accent", "sheet"])
    }
}
