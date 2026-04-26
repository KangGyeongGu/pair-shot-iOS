import Foundation
@testable import PairShot
import XCTest

/// Audit-B — pins the `PrivacyInfo.xcprivacy` entries that surface
/// the Google Mobile Ads SDK's tracking + data-collection footprint
/// to App Store Connect:
///
/// 1. **NSPrivacyTrackingDomains** — must list the four canonical
///    Google ad domains so iOS can route per-domain tracking blocks
///    correctly (rather than blanket-blocking the SDK).
/// 2. **NSPrivacyCollectedDataTypes — AdvertisingData** — must declare
///    the IDFA-derived advertising identifier surface with
///    `Tracking=YES` and `ThirdPartyAdvertising` purpose, mirroring
///    the App Privacy questionnaire for ads-supported apps.
///
/// A missing domain or missing AdvertisingData entry surfaces during
/// App Store Connect's privacy nutrition-label step, but it's much
/// cheaper to catch it on `xcodebuild test` than at submission.
final class PrivacyManifestDomainTests: XCTestCase {
    /// Canonical Google Mobile Ads domains the SDK contacts. Pulled
    /// from Google's developer guidance and the SDK's documented
    /// privacy manifest. Adding a new SDK with its own ad network
    /// requires extending both this list and the manifest.
    private static let requiredTrackingDomains: [String] = [
        "googleads.g.doubleclick.net",
        "googlesyndication.com",
        "googleadservices.com",
        "doubleclick.net",
    ]

    // MARK: - Helpers

    private func loadManifest() -> NSDictionary? {
        guard
            let url = Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? NSDictionary
        else {
            return nil
        }
        return plist
    }

    // MARK: - NSPrivacyTrackingDomains

    func testTrackingDomainsArrayContainsFourGoogleAdDomains() throws {
        let manifest = try XCTUnwrap(loadManifest())
        let domains = try XCTUnwrap(
            manifest["NSPrivacyTrackingDomains"] as? [String],
            "NSPrivacyTrackingDomains must be an array of strings"
        )
        for required in Self.requiredTrackingDomains {
            XCTAssertTrue(
                domains.contains(required),
                "tracking domain \"\(required)\" missing from NSPrivacyTrackingDomains — App Privacy review will flag inconsistency"
            )
        }
    }

    func testTrackingDomainsArrayHasNoEmptyEntries() throws {
        let manifest = try XCTUnwrap(loadManifest())
        let domains = try XCTUnwrap(manifest["NSPrivacyTrackingDomains"] as? [String])
        for (index, entry) in domains.enumerated() {
            XCTAssertFalse(
                entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "domain at index \(index) is empty / whitespace"
            )
        }
    }

    // MARK: - NSPrivacyCollectedDataTypes — AdvertisingData

    func testAdvertisingDataEntryExists() throws {
        let manifest = try XCTUnwrap(loadManifest())
        let collected = try XCTUnwrap(
            manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]]
        )
        let names = collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        XCTAssertTrue(
            names.contains("NSPrivacyCollectedDataTypeAdvertisingData"),
            "AdvertisingData entry missing — Google Mobile Ads SDK requires its IDFA-derived data to be declared"
        )
    }

    func testAdvertisingDataEntryDeclaresTrackingAndThirdPartyPurpose() throws {
        let manifest = try XCTUnwrap(loadManifest())
        let collected = try XCTUnwrap(
            manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]]
        )
        guard let entry = collected.first(where: { entry in
            entry["NSPrivacyCollectedDataType"] as? String
                == "NSPrivacyCollectedDataTypeAdvertisingData"
        }) else {
            XCTFail("AdvertisingData entry missing — covered by previous test")
            return
        }

        let tracking = try XCTUnwrap(
            entry["NSPrivacyCollectedDataTypeTracking"] as? Bool,
            "AdvertisingData entry missing NSPrivacyCollectedDataTypeTracking"
        )
        XCTAssertTrue(
            tracking,
            "AdvertisingData entry must declare Tracking=YES — IDFA usage is by definition cross-app tracking"
        )

        let purposes = try XCTUnwrap(
            entry["NSPrivacyCollectedDataTypePurposes"] as? [String],
            "AdvertisingData entry missing NSPrivacyCollectedDataTypePurposes"
        )
        XCTAssertTrue(
            purposes.contains("NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising"),
            "AdvertisingData purposes must include ThirdPartyAdvertising — Google ad personalization is third-party"
        )
    }
}
