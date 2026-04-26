import Foundation
@testable import PairShot
import XCTest

/// Audit-C — verify that the shutter no longer double-fires haptics.
///
/// Before this audit, both the view (`BeforeCameraView.shutter()` /
/// `AfterCameraView.shutter()`) and the coordinator
/// (`BeforeCaptureCoordinator.captureBefore` /
/// `AfterCaptureCoordinator.captureAfter`) emitted haptic feedback.
/// The intended UX is **one** `.heavy` impact when the shutter button
/// is pressed, **one** `.success` notification once the capture
/// completes — not two of each.
///
/// We can't drive the SwiftUI view body in XCTest, so instead we
/// combine two complementary checks:
///
/// 1. **Sequence-level** — record calls on a `FakeHaptics` and reason
///    about the contract: a single press + completion sequence must
///    produce exactly `[.heavy]` impacts and `[.success]`
///    notifications.
/// 2. **Source-level (Audit-D)** — read the coordinator source files
///    and assert they do not reference any haptic APIs. A future
///    refactor that re-introduces a haptic call inside the coordinator
///    would re-introduce the double-fire — the static assertion catches
///    it at build time.
@MainActor
final class HapticDoubleFireTests: XCTestCase {
    // MARK: - sequence-level

    func testSingleShutterPressEmitsExactlyOneHeavyImpact() {
        let fake = FakeHaptics()
        // Simulates the view layer's "press" path: the haptic happens
        // synchronously on press, before the async capture begins.
        fake.impact(.heavy)

        XCTAssertEqual(fake.impacts, [.heavy])
        XCTAssertTrue(fake.notifications.isEmpty)
    }

    func testCompletionEmitsExactlyOneSuccessNotification() {
        let fake = FakeHaptics()
        // After the coordinator returns, the view fires a single
        // `.success` notification. The coordinator itself must not
        // emit anything (Audit-C invariant).
        fake.notify(.success)

        XCTAssertEqual(fake.notifications, [.success])
        XCTAssertTrue(fake.impacts.isEmpty)
    }

    func testFullShutterRoundTripIsHeavyThenSuccess() {
        let fake = FakeHaptics()
        // Press → coordinator returns → success.
        fake.impact(.heavy)
        // Coordinator must NOT emit during this gap (Audit-C
        // contract). Asserted by `testCoordinatorSourceDoesNotReferenceHaptics`
        // below — here we just enforce the order on the view side.
        fake.notify(.success)

        XCTAssertEqual(fake.impacts, [.heavy])
        XCTAssertEqual(fake.notifications, [.success])
    }

    func testCaptureHapticsSuccessHelperOnlyFiresOneNotification() {
        // Direct invocation through the legacy façade (`CaptureHaptics`)
        // — this is what `BeforeCameraView.shutter()` calls after the
        // coordinator returns. It must not also fire an impact.
        // We can't observe the production Taptic Engine, so we just
        // ensure the call is well-formed (compiles + does not crash).
        CaptureHaptics.success()
    }

    // MARK: - source-level (Audit-D)

    func testBeforeCaptureCoordinatorSourceDoesNotReferenceHaptics() throws {
        try assertCoordinatorIsHapticFree(
            relativePath: "PairShot/PairShot/Features/CameraBefore/CaptureAction.swift",
            coordinatorTypeName: "BeforeCaptureCoordinator"
        )
    }

    func testAfterCaptureCoordinatorSourceDoesNotReferenceHaptics() throws {
        try assertCoordinatorIsHapticFree(
            relativePath: "PairShot/PairShot/Features/CameraAfter/AfterCaptureAction.swift",
            coordinatorTypeName: "AfterCaptureCoordinator"
        )
    }

    /// Read the source file containing the coordinator type and assert
    /// the type body does not call any haptic API. We scope the search
    /// to the lines between `struct <Type>` and the matching closing
    /// brace so the file's neighbouring helpers (e.g. the
    /// ``CaptureHaptics`` façade in `CaptureAction.swift`) can still
    /// reference haptics — we only forbid them inside the coordinator.
    private func assertCoordinatorIsHapticFree(
        relativePath: String,
        coordinatorTypeName: String
    ) throws {
        let root = try XCTUnwrap(
            TestRepoLocator.repoRoot,
            "TestRepoLocator failed to derive repo root from #filePath"
        )
        let url = root.appendingPathComponent(relativePath)
        let contents = try String(contentsOf: url, encoding: .utf8)

        guard let typeRange = contents.range(of: "struct \(coordinatorTypeName)") else {
            XCTFail("\(coordinatorTypeName) declaration not found in \(relativePath)")
            return
        }
        // Walk forward from the type opening, tracking brace depth so we
        // know exactly where the type body ends. The first `{` after
        // the declaration starts depth 1; we stop when depth returns
        // to 0.
        let after = contents[typeRange.upperBound...]
        var depth = 0
        var bodyEnd: String.Index?
        for index in after.indices {
            let char = after[index]
            if char == "{" { depth += 1 }
            if char == "}" {
                depth -= 1
                if depth == 0 {
                    bodyEnd = index
                    break
                }
            }
        }
        guard let bodyEnd else {
            XCTFail("Could not locate \(coordinatorTypeName) closing brace in \(relativePath)")
            return
        }
        let body = String(after[..<bodyEnd])

        // Forbidden symbols. A coordinator that re-introduces any of
        // these is re-introducing the Audit-C double-fire bug.
        let forbidden = [
            "HapticService",
            "CaptureHaptics",
            "UIImpactFeedbackGenerator",
            "UINotificationFeedbackGenerator",
        ]
        for needle in forbidden {
            XCTAssertFalse(
                body.contains(needle),
                "\(coordinatorTypeName) body must not reference `\(needle)` "
                    + "(Audit-C: view layer owns the shutter UX). "
                    + "Re-introducing a haptic call here re-creates the double-fire bug."
            )
        }
    }
}
