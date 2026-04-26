import Foundation
@testable import PairShot
import XCTest

/// P10.3 — `PrivacyInfo.xcprivacy` structural audit.
///
/// Apple's App Store submission pipeline validates the privacy manifest
/// against a fixed schema (NSPrivacyTracking · NSPrivacyTrackingDomains
/// · NSPrivacyAccessedAPITypes · NSPrivacyCollectedDataTypes). A missing
/// key, malformed dict, or incorrect reason code surfaces as a TestFlight
/// upload rejection rather than a runtime error — so we lock the file's
/// shape down with a unit test that runs on every build.
///
/// We load the file from the **app** bundle (`Bundle.main`), not the
/// test bundle, because that's where the manifest is shipped. If
/// `GENERATE_INFOPLIST_FILE = NO` ever gets reverted or the file is
/// removed from the synchronized root group, the very first assertion
/// breaks immediately.
final class PrivacyManifestAuditTests: XCTestCase {
    // MARK: - Helpers

    /// Loads the privacy manifest from the host app's bundle.
    /// Returns `nil` when missing — every test below treats that as a
    /// hard failure rather than skipping silently.
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

    // MARK: - File presence + top-level keys

    func testManifestExistsInAppBundle() throws {
        let manifest = try XCTUnwrap(
            loadManifest(),
            "PrivacyInfo.xcprivacy missing from app bundle — check synchronized group membership"
        )
        XCTAssertGreaterThan(manifest.count, 0)
    }

    func testManifestHasAllFourTopLevelKeys() throws {
        let manifest = try XCTUnwrap(loadManifest())
        XCTAssertNotNil(manifest["NSPrivacyTracking"], "NSPrivacyTracking key required")
        XCTAssertNotNil(
            manifest["NSPrivacyTrackingDomains"],
            "NSPrivacyTrackingDomains key required (may be empty array)"
        )
        XCTAssertNotNil(
            manifest["NSPrivacyAccessedAPITypes"],
            "NSPrivacyAccessedAPITypes key required"
        )
        XCTAssertNotNil(
            manifest["NSPrivacyCollectedDataTypes"],
            "NSPrivacyCollectedDataTypes key required (may be empty if 'Data Not Collected')"
        )
    }

    // MARK: - NSPrivacyAccessedAPITypes

    func testAccessedAPITypesEachHaveTypeAndReasons() throws {
        let manifest = try XCTUnwrap(loadManifest())
        let types = try XCTUnwrap(
            manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]],
            "NSPrivacyAccessedAPITypes must be array of dicts"
        )
        XCTAssertGreaterThan(types.count, 0, "expect at least one accessed API category")
        for (index, entry) in types.enumerated() {
            XCTAssertNotNil(
                entry["NSPrivacyAccessedAPIType"] as? String,
                "entry \(index) missing NSPrivacyAccessedAPIType (string)"
            )
            let reasons = entry["NSPrivacyAccessedAPITypeReasons"] as? [String]
            XCTAssertNotNil(
                reasons,
                "entry \(index) missing NSPrivacyAccessedAPITypeReasons (array of code strings)"
            )
            XCTAssertGreaterThan(
                reasons?.count ?? 0,
                0,
                "entry \(index) reasons must be non-empty"
            )
        }
    }

    func testAccessedAPITypesIncludeUserDefaultsAndDiskSpace() throws {
        let manifest = try XCTUnwrap(loadManifest())
        let types = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let categories = types.compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
        XCTAssertTrue(
            categories.contains("NSPrivacyAccessedAPICategoryUserDefaults"),
            "AppSettings/AdFreeStore use UserDefaults — category must be declared"
        )
        XCTAssertTrue(
            categories.contains("NSPrivacyAccessedAPICategoryDiskSpace"),
            "StorageInfoView reads directorySize — DiskSpace category must be declared"
        )
    }

    // MARK: - NSPrivacyCollectedDataTypes

    func testCollectedDataTypesIncludePreciseLocationAndPhotos() throws {
        let manifest = try XCTUnwrap(loadManifest())
        let collected = try XCTUnwrap(
            manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]],
            "NSPrivacyCollectedDataTypes must be array of dicts"
        )
        let names = collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        XCTAssertTrue(
            names.contains("NSPrivacyCollectedDataTypePreciseLocation"),
            "P1.3 LocationService records GPS — PreciseLocation must be declared"
        )
        XCTAssertTrue(
            names.contains("NSPrivacyCollectedDataTypePhotosorVideos"),
            "Camera + composite pipeline persists JPEGs — PhotosorVideos must be declared"
        )
    }

    func testCollectedDataTypesAreNotTrackingAndIncludeAppFunctionality() throws {
        let manifest = try XCTUnwrap(loadManifest())
        let collected = try XCTUnwrap(manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        for (index, entry) in collected.enumerated() {
            let tracking = try XCTUnwrap(
                entry["NSPrivacyCollectedDataTypeTracking"] as? Bool,
                "entry \(index) missing NSPrivacyCollectedDataTypeTracking"
            )
            XCTAssertFalse(
                tracking,
                "entry \(index): we never use Photo/Location for cross-app tracking"
            )
            let purposes = try XCTUnwrap(
                entry["NSPrivacyCollectedDataTypePurposes"] as? [String],
                "entry \(index) missing NSPrivacyCollectedDataTypePurposes"
            )
            XCTAssertTrue(
                purposes.contains("NSPrivacyCollectedDataTypePurposeAppFunctionality"),
                "entry \(index): all collected data is for app functionality only"
            )
        }
    }
}
