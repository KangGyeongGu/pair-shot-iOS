import CoreLocation
import Foundation
@testable import PairShot
import XCTest

/// Audit-C — `CoreLocationService.requestSingleLocation()` previously
/// canceled any in-flight continuation by resuming it with `nil`,
/// which silently dropped the original caller's result. The new
/// behaviour: a second concurrent call short-circuits to `nil`
/// immediately, leaving the original request to complete normally.
///
/// CLLocationManager can't be driven deterministically from XCTest
/// (the system delegate callbacks need real GPS / a granted user
/// prompt), so the tests below exercise the *contract* via a
/// `LocationProviding` fake that mirrors the production
/// continuation-stash logic.
@MainActor
final class LocationServiceConcurrencyTests: XCTestCase {
    func testSecondConcurrentCallReturnsNilImmediately() async {
        let fake = StashingLocationFake()
        let firstTask = Task { await fake.requestSingleLocation() }
        // Yield so the first call lands inside `withCheckedContinuation`
        // and stashes the continuation.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 30_000_000)

        // The Audit-C guard short-circuits the second call.
        let second = await fake.requestSingleLocation()
        XCTAssertNil(second, "second concurrent call must return nil under the audit-C contract")
        XCTAssertEqual(fake.shortCircuitCount, 1, "guard should fire exactly once")

        // Release the first call so the test doesn't leak the Task.
        fake.complete(with: nil)
        _ = await firstTask.value
    }

    func testSequentialCallsAreNotBlocked() async {
        // After the first call finishes (continuation cleared), a
        // fresh call must proceed normally.
        let fake = StashingLocationFake()

        let firstTask = Task { await fake.requestSingleLocation() }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 30_000_000)
        fake.complete(with: nil)
        _ = await firstTask.value

        // Second call: not concurrent with anything.
        let secondTask = Task { await fake.requestSingleLocation() }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 30_000_000)
        fake.complete(with: nil)
        _ = await secondTask.value

        XCTAssertEqual(fake.admittedCount, 2, "both sequential calls should be admitted")
        XCTAssertEqual(fake.shortCircuitCount, 0, "no calls were concurrent — short-circuit must not fire")
    }

    func testProtocolConformanceCompiles() {
        // Compile-time guard: `LocationProviding` has the expected
        // single-method shape so the production `CoreLocationService`
        // and any test fake can be substituted at the call site.
        let providers: [any LocationProviding] = [
            StashingLocationFake(),
            CoreLocationService(),
        ]
        XCTAssertEqual(providers.count, 2)
    }

    func testProductionServiceExposesSingleShotEntryPoint() {
        // Smoke: instantiate the production class and verify the
        // method signature matches the protocol. We deliberately do
        // NOT invoke it (would prompt the system).
        let service = CoreLocationService()
        let provider: any LocationProviding = service
        _ = provider
    }
}

/// Mirrors the `CoreLocationService` continuation-stash semantics so
/// concurrency invariants can be asserted without touching the system
/// CLLocationManager. The fake's `requestSingleLocation` enters a
/// `withCheckedContinuation` only when no in-flight call exists; a
/// concurrent caller short-circuits to `nil` (the Audit-C contract).
@MainActor
private final class StashingLocationFake: LocationProviding {
    private(set) var admittedCount = 0
    private(set) var shortCircuitCount = 0
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    func requestSingleLocation() async -> CLLocation? {
        guard continuation == nil else {
            shortCircuitCount += 1
            return nil
        }
        admittedCount += 1
        return await withCheckedContinuation { (cont: CheckedContinuation<CLLocation?, Never>) in
            self.continuation = cont
        }
    }

    /// Resolve the in-flight continuation so the test's awaiting Task
    /// can complete and the slot frees up for a subsequent call.
    func complete(with location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }
}
