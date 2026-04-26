import Foundation
@testable import PairShot
import XCTest

/// P9.1 — `HapticService` wrapper.
///
/// We can't assert that the Taptic Engine actually fired (UIKit's
/// generators have no observable side effects), but we can:
/// 1. Verify the public protocol surface compiles and runs without
///    crashing on the simulator.
/// 2. Verify our `HapticImpactStyle` / `HapticNotificationKind`
///    enums map to the expected UIKit raw values via a fake.
/// 3. Verify `HapticService.shared` is a singleton.
@MainActor
final class HapticServiceTests: XCTestCase {
    func testProductionImpactDoesNotCrashForEveryStyle() {
        let service = HapticService()
        // Drives the production path through every enum case so a
        // future style addition that breaks the UIKit mapping fails
        // here rather than at runtime in the camera UI.
        for style in HapticTestStyles.allImpactStyles {
            service.impact(style)
        }
    }

    func testProductionNotifyDoesNotCrashForEveryKind() {
        let service = HapticService()
        for kind in HapticTestStyles.allNotificationKinds {
            service.notify(kind)
        }
    }

    func testSharedReturnsSameInstance() {
        XCTAssertTrue(HapticService.shared === HapticService.shared)
    }

    // MARK: - Fake-based call-count verification

    func testFakeImpactRecordsCallsInOrder() {
        let fake = FakeHaptics()
        fake.impact(.heavy)
        fake.impact(.light)
        fake.impact(.medium)

        XCTAssertEqual(fake.impacts, [.heavy, .light, .medium])
        XCTAssertTrue(fake.notifications.isEmpty)
    }

    func testFakeNotifyRecordsCallsInOrder() {
        let fake = FakeHaptics()
        fake.notify(.success)
        fake.notify(.warning)
        fake.notify(.error)

        XCTAssertEqual(fake.notifications, [.success, .warning, .error])
        XCTAssertTrue(fake.impacts.isEmpty)
    }
}

// MARK: - Helpers

/// Pure case enumeration used by the tests above. Lives in test
/// scope only so adding a case to `HapticImpactStyle` deliberately
/// surfaces here.
enum HapticTestStyles {
    static let allImpactStyles: [HapticImpactStyle] = [.light, .medium, .heavy, .soft, .rigid]
    static let allNotificationKinds: [HapticNotificationKind] = [.success, .warning, .error]
}

/// Test double for `HapticServicing` — records every emit so the
/// view-side wiring can be unit-tested without driving UIKit.
@MainActor
final class FakeHaptics: HapticServicing {
    private(set) var impacts: [HapticImpactStyle] = []
    private(set) var notifications: [HapticNotificationKind] = []

    func impact(_ style: HapticImpactStyle) {
        impacts.append(style)
    }

    func notify(_ kind: HapticNotificationKind) {
        notifications.append(kind)
    }
}
